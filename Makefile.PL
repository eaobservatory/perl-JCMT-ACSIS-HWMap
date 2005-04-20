use ExtUtils::MakeMaker;
WriteMakefile(
  'NAME'         => 'JCMT::ACSIS::HWMap',
  'VERSION_FROM' => 'HWMap.pm',
  'dist'         => { COMPRESS => "gzip -9f" }
  ); 
