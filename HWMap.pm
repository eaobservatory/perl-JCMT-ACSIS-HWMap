package JCMT::ACSIS::HWMap;

=head1 NAME

JCMT::ACSIS::DCM - Hardware mapping for ACSIS

=head1 SYNOPSIS

 use JCMT::ACSIS::HWMap;

 my $map = new JCMT::ACSIS::HWMap( File => $map );

 @dcms = $map->mapping( $receptor );


=head1 DESCRIPTION

This class provides a simple interface to the hardware wiring of ACSIS
from the individual receptors through to the CM, DCMs, quadrants, LOs
and correlator tasks.

=cut

use 5.006;
use strict;
use Carp;
use warnings;

use vars qw/ $VERSION /;

$VERSION = sprintf("%d.%03d", q$Revision$ =~ /(\d+)\.(\d+)/);

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new mapping object. In general, there is only expected to
be one of these objects relevant for a given hardware configuration. Despite
that this is not implemented as a singleton class.

  $map = new JCMT::ACSIS::HWMap( File => $wirefile );

Currently it can only be configured from a wiring file.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Read the arguments
  my %args = @_;

  croak "Must supply File name to constructor\n"
    unless exists $args{File};

  # create the base map
  my $map = bless { 
		   CM => [],
		  };


  $map->_import_file( $args{File} );

  return $map;
}

=back

=head2 Accessor Methods

=over 4

=item B<filename>

Name of wiring file used to construct the object (if any).

=cut

sub filename {
  my $self = shift;
  if (@_) { $self->{FileName} = shift; }
  return $self->{FileName};
}

=item B<map_version>

Version number obtained from the wiring file.

  $v = $map->map_version();

=cut

sub map_version {
  my $self = shift;
  if (@_) {
    $self->{MapVersion} = shift;
  }
  return $self->{MapVersion};
}

=item B<map_date>

Modification date of wiring file.

  $date = $map->map_date();

Date is returned as epoch seconds (for now).

=cut

sub map_date {
  my $self = shift;
  if (@_) {
    $self->{MapDate} = shift;
  }
  return $self->{MapDate};
}

=item B<cm_map>

The primary index for the mapping is by CM_ID. This method returns
an array of hashes containing the low level mapping details for all receptors.

  @map = $map->cm_map();

A new mapping can be stored (over-writing previous mapping).

  $map->cm_map( @newmap );

Each CM is specified by a hash with the following keys:

  RECEPTORS: Reference to array of receptor IDs
  SB_MODES : Reference to corresponding array of subband mode numbers
  QUADRANT
  LO2
  CM_ID
  DCM_ID
  CorrTask

=cut

sub cm_map {
  my $self = shift;
  if (@_) {
    @{$self->{CM}} = @_;
  }
  return @{ $self->{CM} };
}

=back

=head2 General Methods

=over 4

=item B<receptor>

Return the CM mapping for a specified receptor ID. Returns empty list if
the receptor is not available.

  @cm = $map->receptor( "H01" );

Can return multiple hardware mappings for a single pixel. They are returned
in CM_ID order. Each element in the returned list is a reference to a hash
with keys identical to those defined by the C<cm_map> documentation except
that the SB_MODES and RECEPTORS keys will refer to single element arrays.

=cut

sub receptor {
  my $self = shift;
  my $receptor = shift;
  croak "Must supply a receptor to receptor() method\n"
    unless defined $receptor;

  # now get the mapping
  my @map = $self->cm_map;

  my @match;
  for my $cm (@map) {
    # we can not guarantee that every CM_ID is specified
    next unless defined $cm;

    my @receptors = @{ $cm->{RECEPTORS} };

    # need to check each in turn so that we can fix up the SB_MODE array as well
    RECEPTORS: for my $i (0..$#receptors) {
	if ($receptors[$i] eq $receptor) {
	  # take a copy of the hash (so we do not edit the object version)
	  my %map = %$cm;
	  $map{RECEPTORS} = [ $receptor ];
	  $map{SB_MODES}  = [ $cm->{SB_MODES}->[$i] ];
	  push(@match, \%map);
	  last RECEPTORS;
	}
      }
  }
  return @match;
}

=item B<bycmid>

Given a key name in the CM map and a list of CM_IDs, return the 
requested information in CM_ID order.

  @corrtasks = $map->bycmid( "CorrTask", @cmids);

For RECEPTORS, the resulting list will be references to arrays since
a single CM_ID can refer to multiple receptors. For the key definitions
see the C<cm_map> documentation.

Any C<undef>s are removed from the input list.

=cut

sub bycmid {
  my $self = shift;
  my $key = shift;
  my @reqids = grep { defined $_ } @_;

  # get all the mappings
  my @cm = $self->cm_map;

  # we only want information from the requested indices
  return map { $_->{$key} } @cm[@reqids];
}

=back

=begin __PRIVATE_METHODS__

=head2 Private Methods

=over 4

=item B<_import_file>

Read the hardware mapping from the supplied configuration file and configure
the object.

 $map->_import_file( $filename );

=cut

sub _import_file {
  my $self = shift;
  my $file = shift;

  # Open the file and read the contents
  open my $fh, "< $file" or croak "Error opening mapping file $file : $!";
  local $/ = undef;
  my $contents = <$fh>;
  close($fh) or croak "Error closing mapping file $file: $!";

  # Look up the modification date on the file
  my @stat = stat( $file );
  $self->map_date( $stat[9] );

  # parse it
  $self->_import_string( $contents );
  $self->filename( $file );
}

=item B<_import_string>

Given the contents of a hardware mapping file as a single string, extract
the hardware mapping information and configure the object.

  $map->_import_string( $string );

CM_ID is the primary key.

=cut

sub _import_string {
  my $self = shift;
  my $string = shift;

  my @lines = split("\n",$string);

  # Simple text format. "#" is comment line
  # Columns are
  #  CM_ID (primary) DCM_ID QUAD LO2 CorrTask HARP Receptors
  my @cm;
  for my $line (@lines) {
    chomp($line);
    next unless $line =~ /\w/;

    # Spot Revision
    if ($line =~ /\$Revision$/) {
      $self->map_version( $1 );
      next;
    }

    next if $line =~ /^\s*\#/;

    # strip spaces from end of line
    $line =~ s/\s+$//;

    # Multiple non-HARP receptors are allowed
    my ($cmid, $dcmid, $q, $lo, $task, $sbm, $hsbm, $hrec, @recs) = split(/\s+/,$line);

    croak "A HARP receptor was specified but the HARP sideband mode is not an integer\n"
      if $hsbm !~ /^\d+/;
    croak "non-HARP receptor(s) was specified but the sideband mode is not an integer\n"
      if (@recs  && $sbm !~ /^\d+/);

    # Assign the sideband mode to each non-HARP receptor
    my @sbmodes = map { $sbm } @recs;
    push(@sbmodes, $hsbm); # we have already tested validity

    # All the receptors
    push(@recs, $hrec);

    # CM is the unique quantity in the mapping and so can be treated
    # as the index into an array

    $cm[$cmid] = {
		  RECEPTORS => \@recs,
		  SB_MODES => \@sbmodes,
		  QUADRANT => $q,
		  LO2 => $lo,
		  DCM_ID => $dcmid,
		  CM_ID => $cmid,
		  CorrTask => $task,
		 };

  }

  $self->cm_map( @cm );

}

=back

=end __PRIVATE_METHODS__

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

Copyright 2005 Particle Physics and Astronomy Research Council.
All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
