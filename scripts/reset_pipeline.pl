#!/usr/bin/perl
use ExtUtils::MakeMaker;
use Getopt::Long;
use Bio::Pipeline::SQL::DBAdaptor;

my $USAGE =<<END;
***************
Reset Pipeline Script
***************
Usage:
reset_pipeline.pl -h host -u root -p password -d driver -a  pipeline_db_name

Default values are shown below
  -h host     (mysql)
  -u user     (root)
  -d driver   (mysql)
  -p password ()
  -a Not Set  (option to remove inputs from input table)
END

GetOptions(
    'h=s'   => \$DBHOST,
    'u=s'    => \$DBUSER,
    'p=s'    => \$DBPASS,
    'd=s'    => \$DBDRIVER,
    'a'   => \$ALL,
)

or die ($USAGE);
my $DBNAME = $ARGV[0] || die($USAGE);
$DBHOST = $DBHOST || "mysql";
$DBUSER = $DBUSER || "root";
$DBDRIVER = $DBDRIVER || "mysql";


my $db = Bio::Pipeline::SQL::DBAdaptor->new(-dbname=>$DBNAME,-host=>$DBHOST,-user=>$DBUSER,-pass=>$DBPASS,-driver=>$DBDRIVER);

#remove from job table
print STDERR "Removing From job Table\n";
$db->get_JobAdaptor->remove_by_dbID($db->get_JobAdaptor->fetch_all_job_ids);

#remove from new input table
print STDERR "Removing From new_input Table\n";
$db->get_InputAdaptor->remove_new_input_by_dbID();

#remove from output table
print STDERR "Removing From output Table\n";
$db->get_JobAdaptor->remove_outputs_by_job();

#remvoe from completed_jobs table
print STDERR "Removing From completed_jobs Table\n";
$db->get_JobAdaptor->remove_completed_jobs_by_job();

if ($ALL){
    my $proceed = prompt("Do you want to remove all your inputs from the input table? y/n",'n');
    if($proceed =~/^[yY]/){
      $db->get_InputAdaptor->remove_by_dbID();
      print STDERR "Input table cleaned\n\n";
    }
    else {
      print STDERR "I thought not. Exiting...\n";
    }
}

print STDERR "Pipeline Reset Completed\n";









