#!/usr/bin/perl
use Getopt::Long;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::DB::SQL::DBAdaptor;
use ExtUtils::MakeMaker;


my $USAGE =<<END;
**************************
Load Inputs from BioperlDB
**************************
This script loads primary ids of sequences stored inside bioperl-db.
It is really simple and  assumes each sequence will be allocated one job.

Usage: load_biosql.pl -h host -u user -p -password -seqdb dbname -biosql bioperl-db name -biopipe biopipelinename

  -h host     (mysql)
  -u user     (root)
  -d driver   (mysql)
  -p password ()
  -seqdb      (required, the name of the database inside the biodatabase table)
  -biosql     (required, the name of the bioperl-db database)
  -biopipe    (required, the name of the bioperl-pipeline)

END


GetOptions(
    'h=s'         => \$DBHOST,
    'u=s'         => \$DBUSER,
    'd=s'         =>\$DBDRIVER,
    'p=s'         => \$DBPASS,
    'seqdb=s'     =>\$SEQDB,
    'biosql=s'    =>\$BIOSQL,
    'biopipe=s'   =>\$BIOPIPE,

)

or die ($USAGE);

$DBHOST = $DBHOST || "mysql";
$DBUSER = $DBUSER || "root";
$DBPASS = $DBPASS || "";
$DBDRIVER = $DBDRIVER || "mysql";

$BIOSQL || die($USAGE);
$BIOPIPE || die($USAGE);
$SEQDB || die($USAGE);

my $biosql_db = Bio::DB::SQL::DBAdaptor->new(-host  =>$DBHOST,
                                             -dbname=>$BIOSQL,
                                             -driver=>$DBDRIVER,
                                             -user  =>$DBUSER,
                                             -pass  =>$DBPASS);

my $biopipe_db = Bio::Pipeline::SQL::DBAdaptor->new(-host  =>$DBHOST,
                                                    -dbname=>$BIOPIPE,
                                                    -driver=>$DBDRIVER,
                                                    -user  =>$DBUSER,
                                                    -pass  =>$DBPASS);

my @ids = $biosql_db->get_BioDatabaseAdaptor->list_biodatabase_names();
my $biosqlname;
foreach my $id(@ids){
  if($SEQDB eq $id){
    $biosqlname = $SEQDB;
  }
}

$biosqlname || die("Can't find biodatabase of name $SEQDB");

print STDERR "Loading From Database **$biosqlname** in **$BIOSQL**\n";

my $db = $biosql_db->get_BioDatabaseAdaptor->fetch_BioSeqDatabase_by_name($biosqlname);
my $iadp  = $biopipe_db->get_InputAdaptor;
my $jadp = $biopipe_db->get_JobAdaptor;
my @pri_ids = $db->get_all_primary_ids();

my $proceed  = prompt(scalar(@pri_ids)." entries found. Continue load? y/n","n");
if($proceed =~/^[yY]/){
  print STDERR "Loading sequences\n";
  
  my $ih = $biopipe_db->get_IOHandlerAdaptor->fetch_by_dbID(1);

  my $count = 0;
  print STDERR"Please be patient..\n\n";
  foreach my $id(@pri_ids){
    my $anal = Bio::Pipeline::Analysis->new(-id=>1);
    my $input = Bio::Pipeline::Input->new(-name=>$id,-input_handler=>$ih);
    my $job = Bio::Pipeline::Job->new(-analysis=>$anal,-inputs=>[$input],-adaptor=>$jadp);
    my $jid = $jadp->store($job);
    $input->job_id($jid);
    $iadp->store_fixed_input($input);

    #for status
    $count++;
    my $perc = int(($count/(scalar(@pri_ids)))*100);
    my $status = ("*" x $perc) . (" " x (100-$perc));
    print STDERR "[$status]$perc%\r";
  }

}
else {
    print STDERR "Sequences Not loaded. Exiting....\n";
}
  
  
                                          



