use strict;

use Module::Build;

my $build =
    Module::Build->new( module_name => 'Devel::StackTrace',
                        license     => 'perl',
                        requires    => { 'Test::More' => '0.46'
                                       },
                        sign        => 1,
                        create_makefile_pl => 'passthrough',
                      );

$build->create_build_script;
