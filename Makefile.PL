## --Makefile.PL for Bioperl-pipeline distribution--##
## ----------------------------------------------------##
## $Id$
##----------------------------------------------------

#
# Basically this is a standard Makefile with a hash of
# needed packages which are tested at the start
#
# If you want help with this Makefile get in touch with
# the developers by sending a message to bioperl-l@bioperl.org.



# All Bioperl dependencies on external modules are defined here
%packages = (
	     'DBD::mysql'               => '0.0/Mysql driver/loading',
	     );

sub check_package {
    my ($name,$str) = @_;
    my ($ver,$desc,$expl,$module) = split( /\// , $str);
    if( !eval "require($name)") {
	print "External Module $name, $desc,\n is not installed on this computer.\n  The $module in bioperl-pipeline needs it for $expl\n\n";
	return 1;
    }

    return 0;
}

%necessary = (
	'Bio::Tools::Run::Genscan' => 'The bioperl-run package/to run all programs within the pipeline framework',
	'DBD::mysql'               => 'The MySQL drivers (DBD:mysql)/because the bioperl-pipeline is a completely database-centric software which requires MySQL to run'
	);
sub check_necessary_package {
    my ($name,$str) = @_;
    my ($desc,$expl) = split( /\// , $str);
    if( !eval "require($name)") {
        print "WARNING! $desc is not installed on this computer. It is necessary for the bioperl-pipeline $expl\n\n";
	return 1;
    }
return 0;
}
foreach $name ( keys %necessary ) {
	    if( &check_necessary_package($name,$necessary{$name}) == 1 ) {
		            $error = 1;
			        }
			}
			if ($error) {
				        print "INSTALLATION FAILED. The necessary packages/modules detailed above are not present, thus installation cannot proceed. Please install the missing packages/modules and retry\n";
					exit;
				}
	
	
#
# Generate sub testing package system
#
#

# make mini test targets for playing around with
# in testing...

opendir(DIR,"t") || warn "No test directory. Weird!";
@files = readdir(DIR);
shift @files;
shift @files;
foreach my $file (@files) {
    $file =~ /(\w+)\.t/ || next;
    $file = $1;
    $line = "test_$file :: pure_all\n\tPERL_DL_NONLAZY=1 \$(FULLPERL) -I\$(INST_ARCHLIB) -I\$(INST_LIB) -I\$(PERL_ARCHLIB) -I\$(PERL_LIB) -e \'use Test::Harness qw(&runtests \$\$verbose); \$\$verbose=\$(TEST_VERBOSE); runtests \@ARGV;\' t/$file.t\n";
    push(@tline,$line);
    push(@targets,$file);
    $tset  .= "$file \\\n";
}

$tline = join('',@tline);
$tline = "show_tests :\n\t\@echo \'type make test_<subtest> to run\'\n\t\@echo '$tset'\n$tline\n";

print STDERR "Generated sub tests. go make show_tests to see available subtests\n";

sub MY::postamble {
             $tline;
           }

#
# Talk to Elia Stupka (<elia@fugu-sg.org>) or bioperl-l@bioperl.org for more info.
#

# Let the code begin...

require 5.005;
use ExtUtils::MakeMaker;

$do_autoload_finesse = 0;
$NAME     = 'Bio';
$DISTNAME = "bioperl";
$VERSION  = "1.00";

$error = 0;
print "\n";
foreach $name ( keys %packages ) {
    if( &check_package($name,$packages{$name}) == 1 ) {
	$error = 1;
    }
}
foreach $name ( keys %necessary ) {
    if( &check_necessary_package($name,$necessary{$name}) == 1 ) { 
    $error = 1;
    }
}
if( $error == 1 ) {
    print <<QQ_ERROR_QQ;

Warning:

   There are some external packages and perl modules, listed above, which 
   bioperl-pipeline uses. This only effects the functionality which is listed above:
the rest of bioperl will work fine.

   The installation of these external packages is very simple. You
   can read more about bioperl external dependencies at

   http://bioperl.org/Core/external.shtml

   Enjoy the rest of bioperl, which you can use after going 'make install'

QQ_ERROR_QQ
}

WriteMakefile(
    NAME	=> $NAME,
    DISTNAME    => $DISTNAME,
    VERSION     => $VERSION,
    'dist'      => {  COMPRESS     => 'gzip -9f',
                      SUFFIX       => '.gz', 
                      DIST_DEFAULT => 'all tardist',
                   },
    ($] ge '5.005')  ? (
	'AUTHOR' => 'Bioperl Team (bioperl-l@bioperl.org)',
	'ABSTRACT' => 'Bioinformatics Toolkit',
	) : (),
     'realclean'  => {  FILES        => join(' ',@BACKUP_FILES) }
);




