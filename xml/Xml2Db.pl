sub BEGIN {
    push @INC,"/usr/users/kiran/src/xml/XML-SimpleObject0.51/blib/lib";
}
    
use strict;

use XML::Parser;
use XML::SimpleObject;
use Bio::Pipeline::Analysis;
use Bio::Pipeline::Job;
use Bio::Pipeline::Input;
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::DataHandler;
use Bio::Pipeline::Argument;
use Bio::Pipeline::Rule;
use Bio::Pipeline::NodeGroup;
use Bio::Pipeline::Node;
use Bio::Pipeline::SQL::JobAdaptor;
use Bio::Pipeline::SQL::DBAdaptor;
#use Bio::Pipeline::Initializer;
use Getopt::Long;
use ExtUtils::MakeMaker;


use vars qw($DBHOST $DBNAME $DBUSER $DBPASS $DATASETUP $PIPELINEFLOW $JOBFLOW $SCHEMA $INPUT_LIMIT);

$DBHOST ||= "mysql";
$DBNAME ||= "test_XML";
$DBUSER ||= "root";
$DBPASS ||="";
$SCHEMA = $SCHEMA || "/usr/users/shawnh/src/biosql-schema/sql/biopipelinedb-mysql.sql";

my $USAGE =<<END;
******************************
*Xml2DB.pl
******************************
This script configures and creates a pipeline based on xml definitions.

Usage: Xml2DB.pl -dbhost host -dbname pipeline_name -dbuser user -dbpass password -schema /path/to/biopipeline-schema/ -d datasetup.xml -p pipelineflow.xml -j jobflow.xml

Default values in ()
-dbhost host (mysql)
-dbname name of pipeline database (test_XML)
-dbuser user name (root)
-dbpass db password()
-schema The path to the bioperl-pipeline schema.
        Needed if you want to create a new db.
        ($SCHEMA)
-d      the datasetup xml file (required)
-p      the pipelineflow xml file (required)
-j      the job flow xml file (required)
-t      the number of inputs to load for testing


END

GetOptions(
    'dbhost=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'schema=s'    => \$SCHEMA,
    'd=s'         => \$DATASETUP,
    'p=s'         => \$PIPELINEFLOW,
    'j=s'         => \$JOBFLOW,
    't=s'         => \$INPUT_LIMIT
)
or die ($USAGE);

$DATASETUP || die($USAGE);
$PIPELINEFLOW || die($USAGE);
$JOBFLOW || die($USAGE);


 

my $create = prompt("Would you like to delete any existing db named $DBNAME and load a new one?  y/n","n");
if($create =~/^[yY]/){

    if (!-e $SCHEMA){
      warn("$SCHEMA doesn't seem to exist. Please use the -schema option to specify where the biopipeline schema is");
      die(1);
    }
    else {
      system("mysqladmin -u root drop $DBNAME > /dev/null ");
      print STDERR "Creating $DBNAME\n   ";
      system("mysqladmin -u root create $DBNAME ");
      print STDERR "Loading Schema\n";
      system("mysql -u root $DBNAME < $SCHEMA");
   }
}
else {
  print STDERR "Using existing db $DBNAME";
}
my $dba = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
);

my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");


print "Reading Data_setup xml   : $DATASETUP\n";

my $xso1 = XML::SimpleObject->new( $parser->parsefile($DATASETUP) );

my @iohandler_objs;
my $method_id = 1;
foreach my $iohandler ($xso1->child('data_handling_setup')->children('iohandler')) {

  my $ioid = $iohandler->attribute("id");
  my @datahandler_objs;
  my $adaptor_type = $iohandler->child('adaptor_type')->value || "DB";
  my $adaptor_id = $iohandler->child('adaptor_id')->value;
  my $iotype    = $iohandler->child('iohandler_type')->value;
  foreach my $method ($iohandler->children('method')) {
    my $name = $method->child('name')->value;
    my $rank = $method->child('rank')->value;

    my @arg_objs;
    my @arg=$method->children('argument');
    
    foreach my $argument (@arg) {
      if(ref($argument)){ #overcome bug in SimpleObj
        my $tag = $argument->child('tag');
        if (defined ($tag)) { 
          $tag = $argument->child('tag')->value;
        }
        my $value = $argument->child('value')->value;
        my $rank = $argument->child('rank')->value;
        my $type = $argument->child('type')->value;
        my $arg_obj = Bio::Pipeline::Argument->new(-dbID  => $method_id,
                                                   -value => $value,
                                                   -type  => $type,
                                                   -rank  => $rank,
                                                   -tag   => $tag);
        push @arg_objs, $arg_obj;
      }
    }
    my $datahandler_obj = Bio::Pipeline::DataHandler->new(-dbid => $method_id,
                                                          -argument => \@arg_objs,
                                                          -method => $name,
                                                          -rank => $rank);
    $method_id++;
    push @datahandler_objs, $datahandler_obj;
  }

  if ($adaptor_type eq "DB") {
   foreach my $dbadaptor ($xso1->child('data_handling_setup')->children('dbadaptor')) {
     my $id = $dbadaptor->attribute("id");
     if ($adaptor_id == $id) {
      my $dbname = $dbadaptor->child('dbname')->value;
      my $driver = $dbadaptor->child('driver')->value;
      my $host = $dbadaptor->child('host')->value;
      my $user = $dbadaptor->child('user')->value;
      my $password = $dbadaptor->child('password')->value;
      my $module = $dbadaptor->child('module')->value;

      #$dba->store($dbname,$driver,$host,$user,$password,$module);

      my $iohandler_obj = Bio::Pipeline::IOHandler->new_ioh_db(-dbid=>$ioid,
                                                     -type=>$iotype,
                                                     -dbadaptor_dbname=>$dbname,
                                                     -dbadaptor_driver=>$driver,
                                                     -dbadaptor_host=>$host,
                                                     -dbadaptor_user=>$user,
                                                     -dbadaptor_pass=>$password,
                                                     -dbadaptor_module=>$module,
                                                     -datahandlers => \@datahandler_objs);     
      push @iohandler_objs, $iohandler_obj;
     }
    }
   }
   elsif ($adaptor_type eq 'STREAM') {
     foreach my $streamadaptor ($xso1->child('data_handling_setup')->children('streamadaptor')) {
        my $id = $streamadaptor->attribute("id");
        if ($adaptor_id == $id) {
          my $module = $streamadaptor->child('module')->value;
          my $iohandler_obj = Bio::Pipeline::IOHandler->new_ioh_stream (-dbid=>$ioid,
                                                                        -type=>$iotype,
                                                                        -module=>$module,
                                                                        -datahandlers => \@datahandler_objs);

          push @iohandler_objs, $iohandler_obj;
        }
     }
   }
}
    

print "Reading Pipeline_flow xml: $PIPELINEFLOW\n";
my $xso2 = XML::SimpleObject->new( $parser->parsefile($PIPELINEFLOW) );

my @nodegroup_objs;
foreach my $node_group ($xso2->child('pipeline_flow_setup')->children('node_group')) {

    my $nodegroup_id = $node_group->attribute("id");
    my @node_objs;
    my $node_id = 1;
    foreach my $node ($node_group->children('node')) {
      my $name = $node->attribute('name');
      my $node_obj = Bio::Pipeline::Node->new(-id => $node_id,
                                              -current_group => $nodegroup_id,
                                              -name => $name);
      $node_id++;
      push @node_objs, $node_obj;
    }
    
    my $group_name = $node_group->child('name')->value;
    my $group_desc = $node_group->child('description')->value;

    my $nodegroup_obj = Bio::Pipeline::NodeGroup->new(-id => $nodegroup_id,
                                                   -name => $group_name,
                                                   -description => $group_desc,
                                                   -nodes => \@node_objs); 
    push @nodegroup_objs, $nodegroup_obj;
}
my @analysis_objs;
foreach my $analysis ($xso2->child('pipeline_flow_setup')->children('analysis')) {

    my $analysis_obj = Bio::Pipeline::Analysis->new(-id => $analysis->attribute('id'),
                                                -runnable => $analysis->child('runnable')->value);
    my $program = $analysis->child('program');
    my $output_handler_id = $analysis->child('output_iohandler_id');
    my $new_input_handler_id = $analysis->child('new_input_handler_id');
    my $input_handler_id  = $analysis->child('input_iohandler_id');

    my $program_file = $analysis->child('program_file');
    my $db = $analysis->child('db');
    my $db_file = $analysis->child('db_file');
    my $parameters = $analysis->child('parameters');
    my $nodegroup_id = $analysis->child('nodegroup_id');
    my $logic_name = $analysis->child('logic_name');

   if(defined($logic_name)){
       $analysis_obj->logic_name($logic_name->value);
   }
   if (defined($program)){
      $analysis_obj->program($program->value)
   }
   if (defined($program_file)){
      $analysis_obj->program_file($program_file->value)
   }
   if (defined($db)){
      $analysis_obj->db($db->value)
   }
   if (defined($db_file)){
      $analysis_obj->db_file($db_file->value)
   }
   if (defined($parameters)){
      $analysis_obj->parameters($parameters->value)
   }
   if (defined($nodegroup_id)){
      my $node_group = _get_nodegroup($nodegroup_id->value);
      if (!defined($node_group)) {
        #$self->throw("node_group for analysis not found\n");
        print "node_group for analysis not found\n";
      }
      $analysis_obj->node_group($node_group);
   }
   my @ioh;
   if (defined($output_handler_id)){
      my $output_handler = _get_iohandler($output_handler_id->value);
      if (!defined($output_handler)) {
        print "output iohandler for analysis not found\n";
      }
      push @ioh, $output_handler;
   }
   if (defined($input_handler_id)){
       my $input_handler = _get_iohandler($input_handler_id->value);
       if(!defined($input_handler)){
           print "input iohandler fro analysis not found\n";
       }
       push @ioh, $input_handler;
   }
   if (defined($new_input_handler_id)){
      my $new_input_handler = _get_iohandler($new_input_handler_id->value);
      if (!defined($new_input_handler)) {
        print "new input iohandler for analysis not found\n";
      }
      push @ioh, $new_input_handler;
      
   #   $analysis_obj->new_input_handler($new_input_handler);
   }
   $analysis_obj->iohandler(\@ioh);

    foreach my $map ($analysis->children('map_iohandler')){
        if (ref($map)){
          my $prev_iohandler_id = $map->child('prev_iohandler_id');
          my $map_iohandler_id = $map->child('map_iohandler_id');
          if ($prev_iohandler_id && $map_iohandler_id){
      #store to iohandler_map table
          $dba->get_IOHandlerAdaptor->store_map_ioh($analysis_obj->dbID,$prev_iohandler_id->value,$map_iohandler_id->value);
          }
        }
   }
   
   push @analysis_objs, $analysis_obj;
 }

my @rule_objs = ();
foreach my $rule ($xso2->child('pipeline_flow_setup')->children('rule')) {
 if(ref($rule)) {
   my $current = _get_analysis($rule->child('current_analysis_id')->value);
   if (!defined($current)) {
     #$self->throw("current analysis not found for rule\n");
     print "current analysis not found for rule\n";
   }
   my $next = _get_analysis($rule->child('next_analysis_id')->value);
   if (!defined($next)) {
     #$self->throw("next analysis not found for rule\n");
     print "next analysis not found for rule\n";
   }
   my $action = $rule->child('action')->value;
  
   my $rule_obj = Bio::Pipeline::Rule->new(-current=> $current,
                                           -next => $next,
                                           -action => $action);
   push @rule_objs, $rule_obj;
 }
}


#store first before fetching job ids as I need the iohandlers in the db

foreach my $iohandler (@iohandler_objs) {
  $dba->get_IOHandlerAdaptor->store($iohandler);
}

print "Reading Job_flow xml     : $JOBFLOW\n";
my $xso3 = XML::SimpleObject->new( $parser->parsefile($JOBFLOW) );

my @job_objs;

################################################################
#added this functionality for init loading of inputs
#not the prettiest implementation but will re-factor
#with kiran's validating parser --shawn
###############################################################
if ($xso3->child('job_setup')->child('input_create')){
    print "Fetching Input ids \n";
    my $in_c = $xso3->child('job_setup')->child('input_create');
    my $ioh_id       = $in_c->child('iohandler')->attribute("id");
    my $map_id       = $in_c->child('map_ioh')->attribute("id");
    my $ioh = $dba->get_IOHandlerAdaptor->fetch_by_dbID($ioh_id);
    my $map_ioh= $dba->get_IOHandlerAdaptor->fetch_by_dbID($map_id);
    my $anal = _get_analysis(1);
    my ($inputs) = $ioh->fetch_input_ids();
    print scalar(@{$inputs}). " inputs fetched\nStoring...\n";

    my $jobid = 1;
    foreach my $in (@{$inputs}){
        my $input_obj = Bio::Pipeline::Input->new(-name => $in,
                                                  -input_handler => $map_ioh);
        $input_obj->job_id($jobid);
        my @input_objs;
        push @input_objs, $input_obj;
        my $job_obj = Bio::Pipeline::Job->new(-id => $jobid,
                                              -analysis => $anal,
                                              -adaptor => $dba->get_JobAdaptor,
                                              -inputs => \@input_objs);
        push @job_objs, $job_obj;
        $jobid++;
        if($INPUT_LIMIT && $jobid == $INPUT_LIMIT){
            last;}
    }

        

}
else {
foreach my $job ($xso3->child('job_setup')->children('job')) {

   my $id = $job->attribute("id");
   my $process_id = defined($job->child('process_id')) ?$job->child('process_id')->value : '';
   my $queue_id = defined($job->child('queue_id')) ? $job->child('queue_id')->value : '';
   my $retry_count = defined($job->child('retry_count')) ? $job->child('retry_count')->value : '';
   my $analysis = defined($job->child('analysis_id')) ? _get_analysis($job->child('analysis_id')->value) : '';

   my @input_objs;
   foreach my $input ($job->children('fixed_input')) {

     my $input_iohandler = _get_iohandler($input->child('input_iohandler_id')->value);
     if (!defined($input_iohandler)) {
       #$self->throw("Iohandler for input not found\n");
       print "Iohandler for input not found\n";
     }
     my $name = $input->child('name')->value;

     my $input_obj = Bio::Pipeline::Input->new(-name => $name,
                                             -input_handler => $input_iohandler);
     $input_obj->job_id($id);
     push @input_objs, $input_obj;
   }

   my $job_obj = Bio::Pipeline::Job->new(-id => $id,
                                         -process_id => $process_id,
                                         -queue_id => $queue_id,
                                         -retry_count => $retry_count,
                                         -analysis => $analysis,
                                         -adaptor => $dba->get_JobAdaptor,
                                         -inputs => \@input_objs);
   push @job_objs, $job_obj;
}
}

# now the nicest part .. the actual storing.. need to store only 4 objects, 
# iohandler, analysis, job and rule .. these objects will inturn store all the objects that they contain..


foreach my $analysis (@analysis_objs) {
  $dba->get_AnalysisAdaptor->store($analysis);
}
foreach my $job (@job_objs) {
  $dba->get_JobAdaptor->store($job);
}
foreach my $rule (@rule_objs) {
  $dba->get_RuleAdaptor->store($rule);
}

print STDERR "Loading of pipeline $DBNAME completed\n";
sub _get_analysis {
  #my ($self,$id) = @_;
  my ($id) = @_;

  foreach my $analysis(@analysis_objs) {
    if ($analysis->dbID == $id) {
      return $analysis;
    }
  }
  return undef;
}

sub _get_iohandler {
  #my ($self,$id) = @_;
  my ($id) = @_;

  foreach my $iohandler(@iohandler_objs) {
    if ($iohandler->dbID == $id) {
      return $iohandler;
    }
  }
  return undef;
}

sub _get_nodegroup {
  #my ($self,$id) = @_;
  my ($id) = @_;

  foreach my $nodegroup(@nodegroup_objs) {
    if ($nodegroup->id == $id) {
      return $nodegroup;
    }
  }
  return undef;
}
 
