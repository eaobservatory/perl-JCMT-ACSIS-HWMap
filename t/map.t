#  -*-perl-*-

use Test::More tests => 8;
use File::Spec;

require_ok( "JCMT::ACSIS::HWMap" );

# wiring file
my $file = File::Spec->catfile( "t", "wire_file.txt" );


my $map = new JCMT::ACSIS::HWMap( File => $file );
isa_ok( $map, "JCMT::ACSIS::HWMap" );

my @cm = $map->cm_map();

is(@cm, 32, "Count number of CM_IDs in use");

# extract receptor information
@cm = $map->receptor( 'BB' );
is(@cm, 4, "Count number of CM_IDs in use for BB");
@cm = $map->receptor( 'H14' );
is(@cm, 2, "Count number of CM_IDs in use for H14");


# Get information on the corrtasks associated with receptor BB and BA
@cm = $map->receptor('BA');
push(@cm, $map->receptor('BB'));

my @ids = map { $_->{CM_ID} } @cm;
my %uniq = map { $_, undef } @ids;


my @corrtasks = $map->bycmid( 'CorrTask', keys %uniq);
%uniq = map { $_, undef} @corrtasks;
@corrtasks = keys %uniq;
is(@corrtasks, 2, "Count number of corrtasks used for RxB");
is($corrtasks[0], 1, "First corrtask");
is(@corrtasks[1], 5, "Second corrtask");

