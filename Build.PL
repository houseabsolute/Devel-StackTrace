use strict;

use Module::Build;

my $build =
    Module::Build->new( module_name => 'Devel::StackTrace',
                        license     => 'perl',
                        requires    => { 'Test::More' => '0.46',
                                         'File::Spec' => 0,
                                       },
                        sign        => 1,
                        create_makefile_pl => 'traditional',
                        create_readme      => 1,
                      );

$build->create_build_script;
