##############################################################
#Xml2Db.pl
#This script is used to load the pipeline up from the 
#pipeline_setup.xml
#You will need to have XML::SimpleObject installed for this script
#to work.
##############################################################

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
use Getopt::Long;
use ExtUtils::MakeMaker;


use vars qw($DBHOST $DBNAME $DBUSER $DBPASS $DATASETUP $PIPELINEFLOW $JOBFLOW $SCHEMA $INPUT_LIMIT);

$DBHOST ||= "mysql";
$DBNAME ||= "test_XML";
$DBUSER ||= "root";
$DBPASS ||="";
$SCHEMA = $SCHEMA || "/usr/users/kiran/src/bioperl-pipeline/t/data/schema.sql";

my $USAGE =<<END;
******************************
*Xml2DB.pl
******************************
This script configures and creates a pipeline based on xml definitions.

Usage: Xml2DB.pl -dbhost host -dbname pipeline_name -dbuser user -dbpass password -schema /path/to/biopipeline-schema/ -p pipeline_setup.xml

Default values in ()
-dbhost host (mysql)
-dbname name of pipeline database (test_XML)
-dbuser user name (root)
-dbpass db password()
-schema The path to the bioperl-pipeline schema.
        Needed if you want to create a new db.
        ($SCHEMA)
-p      the pipeline setup xml file (required)


END

GetOptions(
    'dbhost=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'schema=s'    => \$SCHEMA,
    'p=s'         => \$DATASETUP,
)
or die ($USAGE);

$DATASETUP || die($USAGE);

################################
#Setting up the pipeline database
################################

my $create = prompt("Would you like to delete any existing db named $DBNAME and load a new one?  y/n","n");
if($create =~/^[yY]/){

    if (!-e $SCHEMA){
      warn("$SCHEMA doesn't seem to exist. Please use the -schema option to specify where the biopipeline schema is");
      die(1);
    }
    else {
      system("mysqladmin -u root -f drop $DBNAME > /dev/null ");
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

##############################################
#Start the Parsing and loading of the pipeline
##############################################
my $parser = XML::Parser->new(ErrorContext => 2, Style => "Tree");

print "Reading Data_setup xml   : $DATASETUP\n";

my $xso1 = XML::SimpleObject->new( $parser->parsefile($DATASETUP) );

my @iohandler_objs;
my $method_id = 1;

############################################
#Load DBAdaptor and IOHandler information
############################################

print "Doing DBAdaptor and IOHandler setup\n";
foreach my $iohandler ($xso1->child('pipeline_setup')->child('iohandler_setup')->children('iohandler')) {

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
   foreach my $dbadaptor ($xso1->child('pipeline_setup')->child('database_setup')->children('dbadaptor')) {
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
     foreach my $streamadaptor ($xso1->child('pipeline_setup')->child('database_setup')->children('streamadaptor')) {
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
    

############################################
#Load Analysis and Rules information 
############################################
my @nodegroup_objs;
print "Doing Pipeline Flow Setup\n";

foreach my $node_group ($xso1->child('pipeline_setup')->child('pipeline_flow_setup')->children('node_group')) {

  if (ref($node_group)){
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
}

my @pipeline_converter_objs;
print "Doing Converters..\n";
foreach my $converter ($xso1->child('pipeline_setup')->child('pipeline_flow_setup')->children('converter')) {
   
  if (ref($converter)) {
     my $converter_obj = Bio::Pipeline::Converter->new(-dbID => $converter->attribute('id'),
                                                     -module => $converter->child('module')->value,
                                                     -method => $converter->child('method')->value);
     push @pipeline_converter_objs, $converter_obj;
  }
}


my @analysis_objs;
print "Doing Analysis..\n";
foreach my $analysis ($xso1->child('pipeline_setup')->child('pipeline_flow_setup')->children('analysis')) {

    my $analysis_obj;
    my $datamonger = $analysis->child('data_monger');
    if (defined $datamonger) {
        my @datamonger_iohs;
        $analysis_obj = Bio::Pipeline::Analysis->new(-id => $analysis->attribute('id'),
                                                   -runnable => 'Bio::Pipeline::Runnable::DataMonger',
                                                   -logic_name => 'DataMonger',
                                                   -program => 'DataMonger');
        
        my @initial_input_objs; 
        my $input_present_flag = 0;
    	foreach my $input ($datamonger->children('input')){
         if (ref ($input)) {
           $input_present_flag = 1;
           my $name = $input->child('name')->value;
           my $input_iohandler_id = $input->child('iohandler')->value;
          my $tag = defined($input->child('tag')) ? $input->child('tag')->value : 'input';
           my $input_iohandler_obj = _get_iohandler($input_iohandler_id);
           push @datamonger_iohs, $input_iohandler_obj;
           my $initial_input_obj = Bio::Pipeline::Input->new(-name => $name,
                                                             -tag => $tag,
                                                             -job_id => 1,
                                                             -input_handler => $input_iohandler_obj);
           push @initial_input_objs, $initial_input_obj;
         }
        }
        if ($input_present_flag) {
          _create_initial_input_and_job($analysis_obj,@initial_input_objs); 
        }



        my $datamonger_obj = Bio::Pipeline::Runnable::DataMonger->new();
    	foreach my $filter ($datamonger->children('filter')){
         if (ref ($filter)) {
           my $module = $filter->child('module')->value;
           my $rank = $filter->child('rank')->value;
           my @arguments = ();      
           foreach my $argument ($filter->children('argument')){
           	my $tag = $argument->child('tag')->value;
           	my $value = $argument->child('value')->value;
                my $argument = Bio::Pipeline::Argument->new(-tag => $tag, -value => $value);
                push @arguments, $argument;
           }
           my $filter = Bio::Pipeline::Filter->new(-module => $module, -rank => $rank);
           $filter->arguments(\@arguments);
           $datamonger_obj->add_filter($filter);
         }
 
        }

        foreach my $input_create ($datamonger->children('input_create')){
         if(ref ($input_create)) {
           my $module = $input_create->child('module')->value;
           my $rank = $input_create->child('rank')->value;
           my @arguments = ();
           my @arguments_hash;
           foreach my $argument ($input_create->children('argument')){
                my $tag = $argument->child('tag')->value;
                my $value = $argument->child('value')->value;
                push @arguments_hash, $tag;
                push @arguments_hash, $value;
                my $argument = Bio::Pipeline::Argument->new(-tag => $tag, -value => $value);
                push @arguments, $argument;
           }
           my $input_create = Bio::Pipeline::InputCreate->new(-module => $module, -rank => $rank, @arguments_hash);
           $input_create->arguments(\@arguments);
           $datamonger_obj->add_input_create($input_create);
         }
        }
        $analysis_obj->data_monger($datamonger_obj);
        $analysis_obj->iohandler(\@datamonger_iohs);
        #push @analysis_objs, $analysis_obj;
        #next;
     } else {

    	$analysis_obj = Bio::Pipeline::Analysis->new(-id => $analysis->attribute('id'),
                                                -runnable => $analysis->child('runnable')->value);
    	my $program = $analysis->child('program');

    	my $program_file = $analysis->child('program_file');
    	my $db = $analysis->child('db');
    	my $db_file = $analysis->child('db_file');
    	my $parameters = $analysis->child('parameters');
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
    }
   my $nodegroup_id = $analysis->child('nodegroup_id');
   if (defined($nodegroup_id)){
      my $node_group = _get_nodegroup($nodegroup_id->value);
      if (!defined($node_group)) {
        print "node_group for analysis not found\n";
      }
      $analysis_obj->node_group($node_group);
   }
   my @ioh;

   foreach my $input_iohandler ($analysis->child('input_iohandler')) {
     if (defined($input_iohandler)){
         my $input_iohandler_obj = _get_iohandler($input_iohandler->attribute("id"));
         if(!defined($input_iohandler_obj)){
            print "input iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @converter_objs;
            foreach my $converter ($input_iohandler->child('converter')) {
              my $converter_obj = _get_converter($converter->attribute("id")); 
              if(defined($converter_obj)){
                 $converter_obj->rank($converter->attribute("rank"));
                 push @converter_objs, $converter_obj;
              } else {
                 print "converter for analysis  not found\n";
              }
            }
            $input_iohandler_obj->converters(\@converter_objs);
            $input_iohandler_obj->type('INPUT');;
            push @ioh, $input_iohandler_obj;
         }
     }
   }

   foreach my $output_iohandler ($analysis->child('output_iohandler')) {
     if (defined($output_iohandler)){
         my $output_iohandler_obj = _get_iohandler($output_iohandler->attribute("id"));
         if(!defined($output_iohandler_obj)){
            print "output iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @converter_objs;
            foreach my $converter ($output_iohandler->child('converter')) {
              my $converter_obj = _get_converter($converter->attribute("id"));
              if(defined($converter_obj)){
                 $converter_obj->rank($converter->attribute("rank"));
                 push @converter_objs, $converter_obj;
              } else {
                 print "converter for analysis  not found\n";
              }
            }
            $output_iohandler_obj->converters(\@converter_objs);
            $output_iohandler_obj->type('OUTPUT');
            push @ioh, $output_iohandler_obj;
         }
     }
   }

    foreach my $map ($analysis->children('input_iohandler_mapping')){
        if (ref($map)){
          my $prev_iohandler_id = $map->child('prev_analysis_iohandler_id');
          my $current_iohandler_id = $map->child('current_analysis_iohandler_id');
          if ($prev_iohandler_id && $current_iohandler_id){
                  my $current_iohandler = _get_iohandler($current_iohandler_id->value);
                  if (!defined($current_iohandler)) {
                     print "current input iohandler for analysis not found\n";
                  }
                  push @ioh, $current_iohandler;
                  #store to iohandler_map table
                  $dba->get_IOHandlerAdaptor->store_map_ioh($analysis_obj->dbID,$prev_iohandler_id->value,$current_iohandler_id->value);
          }
        }
   }

   foreach my $new_input_iohandler ($analysis->child('new_input_iohandler')) {
     if (defined($new_input_iohandler)){
         my $new_input_iohandler_obj = _get_iohandler($new_input_iohandler->attribute("id"));
         if(!defined($new_input_iohandler_obj)){
            print "new_input iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @converter_objs;
            foreach my $converter ($new_input_iohandler->child('converter')) {
              my $converter_obj = _get_converter($converter->attribute("id"));
              if(defined($converter_obj)){
                 $converter_obj->rank($converter->attribute("rank"));
                 push @converter_objs, $converter_obj;
              } else {
                 print "converter for analysis  not found\n";
              }
            }
            $new_input_iohandler_obj->converters(\@converter_objs);
            $new_input_iohandler_obj->type('NEW_INPUT');
            push @ioh, $new_input_iohandler_obj;
         }
     }
   }


   $analysis_obj->iohandler(\@ioh);

   

   push @analysis_objs, $analysis_obj;
 }

my @rule_objs = ();
print "Doing Rules\n";
foreach my $rule ($xso1->child('pipeline_setup')->child('pipeline_flow_setup')->children('rule')) {
 if(ref($rule)) {
   my $current;
   if (defined $rule->child('current_analysis_id')) {
     $current = _get_analysis($rule->child('current_analysis_id')->value);
     if (!defined($current)) {
       print "current analysis not found for rule\n";
     }
   }
   my $next = _get_analysis($rule->child('next_analysis_id')->value);
   if (!defined($next)) {
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
  $dba->get_IOHandlerAdaptor->store_if_needed($iohandler);
}
my @job_objs;


############################################
#Load Jobs if provided 
############################################
print "Doing Job Setup...\n";
if($xso1->child('pipeline_setup')->child('job_setup')){
foreach my $job ($xso1->child('pipeline_setup')->child('job_setup')->children('job')) {
  if (ref($job)) {
   my $id = $job->attribute("id");
   my $process_id = defined($job->child('process_id')) ?$job->child('process_id')->value : '';
   my $queue_id = defined($job->child('queue_id')) ? $job->child('queue_id')->value : '';
   my $retry_count = defined($job->child('retry_count')) ? $job->child('retry_count')->value : '';
   my $analysis = defined($job->child('analysis_id')) ? _get_analysis($job->child('analysis_id')->value) : '';
   my $status = defined($job->child('status')) ? $job->child('status')->value : '';

   my @input_objs;
   foreach my $input ($job->children('fixed_input')) {

     my $input_iohandler = _get_iohandler($input->child('input_iohandler_id')->value);
     if (!defined($input_iohandler)) {
       #$self->throw("Iohandler for input not found\n");
       print "Iohandler for input not found\n";
     }
     my $tag = defined($input->child('tag')) ? $input->child('tag')->value : 'input';
     my $name = $input->child('name')->value;

     my $input_obj = Bio::Pipeline::Input->new(-name => $name,
                                               -tag=>$tag,
                                             -input_handler => $input_iohandler);
     $input_obj->job_id($id);
     push @input_objs, $input_obj;
   }

   my $job_obj = Bio::Pipeline::Job->new(-id => $id,
                                         -process_id => $process_id,
                                         -queue_id => $queue_id,
                                         -retry_count => $retry_count,
                                         -analysis => $analysis,
                                         -status =>$status,
                                         -adaptor => $dba->get_JobAdaptor,
                                         -inputs => \@input_objs);
   push @job_objs, $job_obj;
  }
}
}

###############################################################################################
# now the nicest part .. the actual storing.. need to store only 4 objects, 
# iohandler, analysis, job and rule .. these objects will inturn store all the objects that they contain..
###############################################################################################


foreach my $converter (@pipeline_converter_objs) {
  $dba->get_ConverterAdaptor->store($converter);
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

print STDERR "Loading of pipeline $DBNAME completed\n";

####################################################################
#Utility Methods
####################################################################

sub _create_initial_input_and_job {
  my ($analysis_obj, @initial_input_objs)= @_;
  my $job_obj = Bio::Pipeline::Job->new(-analysis => $analysis_obj,
                                         -retry_count => 3,
                                         -adaptor => $dba->get_JobAdaptor,
                                         -inputs => \@initial_input_objs);
  $dba->get_JobAdaptor->store($job_obj);
}

sub _get_converter {
  my ($id) = @_;

  foreach my $converter(@pipeline_converter_objs) {
    if ($converter->dbID == $id) {
      return $converter;
    }
  }
  return undef;
}

sub _get_analysis {
  my ($id) = @_;

  foreach my $analysis(@analysis_objs) {
    if ($analysis->dbID == $id) {
      return $analysis;
    }
  }
  return undef;
}

sub _get_iohandler {
  my ($id) = @_;

  foreach my $iohandler(@iohandler_objs) {
    if ($iohandler->dbID == $id) {
      return $iohandler;
    }
  }
  return undef;
}

sub _get_nodegroup {
  my ($id) = @_;

  foreach my $nodegroup(@nodegroup_objs) {
    if ($nodegroup->id == $id) {
      return $nodegroup;
    }
  }
  return undef;
}
 
