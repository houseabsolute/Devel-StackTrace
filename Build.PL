
use Module::Build;

my $b = Module::Build->new
  (
   module_name => 'Devel::StackTrace',
   license => 'perl',
   requires => {
                 Test::More => '0.46'
               },
   create_makefile_pl => 'passthrough',
  );
  
$b->create_build_script;
