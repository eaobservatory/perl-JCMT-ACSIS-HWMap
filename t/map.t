#  -*-perl-*-

use Test::More tests => 5;
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
