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
use Bio::Pipeline::SQL::DBAdaptor;

use Getopt::Long;

use Bio::Pipeline::PipeConf qw (DBHOST
                                DBNAME
                                DBUSER
                                DBPASS
                               );


GetOptions(
    'host=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
)
or die ("Couldn't get options");

my $dba = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
);




my $file1 = shift;
my $file2 = shift;
my $file3 = shift;


#my $file1 = 'data_setup.xml';
#my $file2 = 'pipeline_flow_setup.xml';
#my $file3 = 'job_setup.xml';

my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");


print "File1 : $file1\n";
print "File2 : $file2\n";
print "File3 : $file3\n";

my $xso1 = XML::SimpleObject->new( $parser->parsefile($file1) );

my @iohandler_objs;
foreach my $iohandler ($xso1->child('data_handling_setup')->children('iohandler')) {

  my $ioid = $iohandler->attribute("id");
  my @datahandler_objs;
  my $adaptor_type = $iohandler->child('adaptor_type')->value;
  my $adaptor_id = $iohandler->child('adaptor_id')->value;
  foreach my $method ($iohandler->children('method')) {
    my $name = $method->child('name')->value;
    my $rank = $method->child('rank')->value;

    my @arg_objs;
    foreach my $argument ($method->children('argument')) {
      my $tag = $argument->child('name');
      if (defined ($tag)) { 
        $tag = $argument->child('name')->value;
      }
      my $value = $argument->child('value')->value;
      my $rank = $argument->child('rank')->value;
      my $type = $argument->child('type')->value;
      my $arg_obj = Bio::Pipeline::Argument->new(-dbID => 1,
                                                -value => $value,
                                                -type => $type,
                                                -rank => $rank,
                                                -tag => $tag);
      push @arg_objs, $arg_obj;
    }
    my $datahandler_obj = Bio::Pipeline::DataHandler->new(-dbid => 1,
                                                     -argument => \@arg_objs,
                                                     -method => $name,
                                                     -rank => $rank);
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
                                                                        -module=>$module,
                                                                        -datahandlers => \@datahandler_objs);

          push @iohandler_objs, $iohandler_obj;
        }
     }
   }
}
    

my $xso2 = XML::SimpleObject->new( $parser->parsefile($file2) );

my @nodegroup_objs;
foreach my $node_group ($xso2->child('pipeline_flow_setup')->children('node_group')) {

    my $nodegroup_id = $node_group->attribute("id");
    my @node_objs;
    foreach my $node ($node_group->children('node')) {
      my $name = $node->attribute('name');
      my $node_obj = Bio::Pipeline::Node->new(-id => 1,
                                              -current_group => $nodegroup_id,
                                              -name => $name);
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
    my $output_handler_id = $analysis->child('output_handler_id');
    my $new_input_handler_id = $analysis->child('new_input_handler_id');
    my $program_file = $analysis->child('program_file');
    my $db = $analysis->child('db');
    my $db_file = $analysis->child('db_file');
    my $parameters = $analysis->child('parameters');
    my $nodegroup_id = $analysis->child('nodegroup_id');


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
   if (defined($output_handler_id)){
      my $output_handler = _get_iohandler($output_handler_id->value);
      if (!defined($output_handler)) {
        #$self->throw("output iohandler for analysis not found\n");
        print "output iohandler for analysis not found\n";
      }
      $analysis_obj->output_handler($output_handler);
   }
   if (defined($new_input_handler_id)){
      my $new_input_handler = _get_iohandler($new_input_handler_id->value);
      if (!defined($new_input_handler)) {
        #$self->throw("new input iohandler for analysis not found\n");
        print "new input iohandler for analysis not found\n";
      }
      $analysis_obj->new_input_handler($new_input_handler);
   }
   
   push @analysis_objs, $analysis_obj;
 }

my @rule_objs;
foreach my $rule ($xso2->child('pipeline_flow_setup')->children('rule')) {

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


my $xso3 = XML::SimpleObject->new( $parser->parsefile($file3) );

my @job_objs;
foreach my $job ($xso3->child('job_setup')->children('job')) {

   my $id = $job->attribute("id");
   my $process_id = $job->child('process_id')->value;
   my $queue_id = $job->child('queue_id')->value;
   my $retry_count = $job->child('retry_count')->value;
   my $analysis = _get_analysis($job->child('analysis_id')->value);

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



# now the nicest part .. the actual storing.. need to store only 4 objects, 
# iohandler, analysis, job and rule .. these objects will inturn store all the objects that they contain..


foreach my $iohandler (@iohandler_objs) {
  $dba->get_IOHandlerAdaptor->store($iohandler);
}
foreach my $analysis (@analysis_objs) {
  $dba->get_AnalysisAdaptor->store($analysis);
}
foreach my $job (@job_objs) {
  $dba->get_JobAdaptor->store($job);
}
foreach my $rule (@rule_objs) {
  $dba->get_RuleAdaptor->store($rule);
}








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
 
