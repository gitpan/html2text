use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	        => 'html2text',
    'EXE_FILES'         => [ 'html2text.pl' ],
    'PREREQ_PM'         => 
    {
        'Text::Format'          => 0,
        'HTML::TreeBuilder'     => 0,
    },
    'VERSION_FROM'      => 'html2text.pl', # finds $VERSION
    'dist'         => {
        'COMPRESS' => 'gzip',
        'SUFFIX'   => 'gz',
    },
);
