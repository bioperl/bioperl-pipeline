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
use Bio::Pipeline::Runnable::DataMonger;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::Filter;
use Bio::Pipeline::Converter;
use Getopt::Long;
use ExtUtils::MakeMaker;


use vars qw($DBHOST $DBNAME $DEBUG $DBUSER $DBPASS $DATASETUP $PIPELINEFLOW $JOBFLOW $SCHEMA $INPUT_LIMIT);

$DBHOST ||= "mysql";
$DBNAME ||= "test_XML";
$DBUSER ||= "root";
$SCHEMA = $SCHEMA || "../sql/schema.sql";

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
-verbose For debugging
-p      the pipeline setup xml file (required)


END

GetOptions(
    'dbhost=s'      => \$DBHOST,
    'dbname=s'    => \$DBNAME,
    'dbuser=s'    => \$DBUSER,
    'dbpass=s'    => \$DBPASS,
    'schema=s'    => \$SCHEMA,
    'verbose'     => $DEBUG,
    'p=s'         => \$DATASETUP,
)
or die ($USAGE);

$DATASETUP || die($USAGE);

################################
#Setting up the pipeline database
################################

my $dba;

eval{
  $dba = Bio::Pipeline::SQL::DBAdaptor->new(
    -host   => $DBHOST,
    -dbname => $DBNAME,
    -user   => $DBUSER,
    -pass   => $DBPASS,
  );
};

my $db_exist;
if(ref $dba){ #able to connect 
    $db_exist=1;
}
else {
    $db_exist=0;
}

#connect string
my $str;
$str .= defined $DBHOST ? "-h $DBHOST " : "";
$str .= defined $DBPASS ? "-p$DBPASS " : "";
$str .= defined $DBUSER ? "-u $DBUSER " : "-u root ";

if($db_exist){
    
  my $create = prompt("A database called $DBNAME already exists.\nContinuing would involve dropping this database and loading a fresh one using $DATASETUP.\nWould you like to continue? y/n","n");
  if($create =~/^[yY]/){
      print STDERR "Dropping Databases\n";      
      system("mysqladmin $str drop $DBNAME > /dev/null ");
   }
  else {
    print STDERR "Please select another database before running this script. Good bye.\n";
    exit(1);
  }
}

if (!-e $SCHEMA){
  warn("$SCHEMA doesn't seem to exist. Please use the -schema option to specify where the biopipeline schema is");
  exit(1);
}
else {
    print STDERR "Creating $DBNAME\n   ";
    system("mysqladmin $str create $DBNAME");
    print STDERR "Loading Schema...\n";
    system("mysql $str $DBNAME < $SCHEMA");
    $dba = Bio::Pipeline::SQL::DBAdaptor->new(-host   => $DBHOST,
                                              -dbname => $DBNAME,
                                              -user   => $DBUSER,
                                              -pass   => $DBPASS);
}

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

my $pipeline_setup  = $xso1->child('pipeline_setup') || die("Pipeline template missing <pipeline_setup>\n Please provide a valid one");
my $iohandler_setup = $pipeline_setup->child('iohandler_setup') || goto PIPELINE_FLOW_SETUP;

#die("Pipeline template missing <iohandler_setup>\n Please provide a valid one");

foreach my $iohandler ($iohandler_setup->children('iohandler')) {
    $iohandler || next;
   my %iohandler_attrs = $iohandler->attributes;
   
  my $ioid = $iohandler->attribute("id");
  my @datahandler_objs;

#  my $adaptor_type = &verify ($iohandler,'adaptor_type','REQUIRED','DB');

#  my $adaptor_id = &verify($iohandler,'adaptor_id','REQUIRED');

my %adaptor_attrs;
if(defined($iohandler->child('adaptor'))){
    my $adaptor = $iohandler->child('adaptor');
    %adaptor_attrs = $adaptor->attributes;
}

my $adaptor_type;
if(defined($iohandler->child('adaptor_type') )){
    $adaptor_type = $iohandler->child('adaptor_type')->value ;
}elsif(exists $adaptor_attrs{'type'}){
    $adaptor_type = $adaptor_attrs{'type'};
}else{
    $adaptor_type = "DB";
}

my $adaptor_id;
if(defined $iohandler->child('adaptor_id') ){
    $adaptor_id = $iohandler->child('adaptor_id')->value;
}elsif(exists $adaptor_attrs{'id'}){
    $adaptor_id = $adaptor_attrs{'id'};
}
  my $iotype     = &verify($iohandler,'iohandler_type','REQUIRED', '', 'type');
  
  my @method = $iohandler->children('method');

  foreach my $method (@method) {
    my $name = &verify($method,'name','REQUIRED', '', 'name');
    my $rank = &verify($method,'rank','REQUIRED',1, 'rank');

    my @arg_objs;
    my @arg=$method->children('argument');
    
    foreach my $argument (@arg) {
      if(ref($argument)){ #overcome bug in SimpleObj
        my $tag = &verify($argument,'tag','OPTIONAL', '', 'tag');
        my $value = &verify($argument,'value','REQUIRED');
        my $rank  = &verify($argument,'rank','OPTIONAL',1);
        my $type  = &verify($argument,'type','OPTIONAL',"SCALAR");

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
   my $database_setup = $pipeline_setup->child('database_setup') || die("Database setup template missing <database_setup>\n Please provide a valid one");

   foreach my $dbadaptor ($database_setup->children('dbadaptor')) {
     my $id = $dbadaptor->attribute("id");
     if ($adaptor_id == $id) {
      my $dbname = &verify($dbadaptor,'dbname','REQUIRED');
      my $driver = &verify($dbadaptor,'driver','OPTIONAL','mysql');
      my $host = &verify($dbadaptor,'host','OPTIONAL','localhost');
      my $user = &verify($dbadaptor,'user','OPTIONAL','root');
      my $password = &verify($dbadaptor,'password','OPTIONAL');
      my $module = &verify($dbadaptor,'module','REQUIRED');

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
     my $database_setup = $pipeline_setup->child('database_setup') || die("Database setup template missing <database_setup>\n Please provide a valid one");
     foreach my $streamadaptor ($database_setup->children('streamadaptor')) {
        my $id = $streamadaptor->attribute("id");
        if ($adaptor_id == $id) {
          my $module = &verify($streamadaptor,'module','REQUIRED');
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

PIPELINE_FLOW_SETUP: my @nodegroup_objs;
print "Doing Pipeline Flow Setup\n";

my $pipeline_flow_setup = $pipeline_setup->child('pipeline_flow_setup') || die("Pipeline setup template missing <pipeline_flow_setup>\n Please provide a valid one");
foreach my $node_group ($pipeline_flow_setup->children('node_group')) {

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
    
    my $group_name = &verify($node_group,'name','REQUIRED');
    my $group_desc = &verify($node_group,'description','OPTIONAL');

    my $nodegroup_obj = Bio::Pipeline::NodeGroup->new(-id => $nodegroup_id,
                                                   -name => $group_name,
                                                   -description => $group_desc,
                                                   -nodes => \@node_objs); 
    push @nodegroup_objs, $nodegroup_obj;
  }
}

my @pipeline_converter_objs;
print "Doing Converters..\n";
foreach my $converter ($pipeline_flow_setup->children('converter')) {
   
  if (ref($converter)) {
      my $module = &verify($converter,'module','REQUIRED');
      my $method= &verify($converter,'method','REQUIRED');
     my $converter_obj = Bio::Pipeline::Converter->new(-dbID => $converter->attribute('id'),
                                                     -module => $module,
                                                     -method => $method);
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
           my $name = &verify($input,'name','REQUIRED');
           my $input_iohandler_id = &verify($input,'iohandler','OPTIONAL','0');

           my $tag = &verify($input,'tag','OPTIONAL','input');
           my $input_iohandler_obj = _get_iohandler($input_iohandler_id) if $input_iohandler_id;

           push @datamonger_iohs, $input_iohandler_obj if $input_iohandler_obj;

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
           my $module = &verify($filter,'module','REQUIRED');
           my $rank = &verify($filter,'rank','OPTIONAL',1);
           my @arguments = ();      
           foreach my $argument ($filter->children('argument')){
           	my $tag = &verify($argument,'tag','OPTIONAL');
           	my $value = &verify($argument,'value','REQUIRED');
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
           my $module = &verify($input_create,'module','REQUIRED');
           my $rank = &verify($input_create,'rank','OPTIONAL',1);
           my @arguments = ();
           my @arguments_hash;
           foreach my $argument ($input_create->children('argument')){
                my $tag = &verify($argument,'tag','OPTIONAL');
                my $value = &verify($argument,'value','REQUIRED');
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
      my $runnable = &verify($analysis,'runnable','REQUIRED');
    	$analysis_obj = Bio::Pipeline::Analysis->new(-id => $analysis->attribute('id'),
                                                -runnable => $runnable);
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
#        print "node_group for analysis not found\n";
      }
      else {
        $analysis_obj->node_group($node_group);
      }
        
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
foreach my $rule ($pipeline_flow_setup->children('rule')) {
 if(ref($rule)) {
   my $current;
   if (defined $rule->child('current_analysis_id')) {

       #should be optional?
       my $anal_id = &verify($rule,'current_analysis_id','OPTIONAL', '', 'current');
       $current = _get_analysis($anal_id);
     if (!defined($current)) {
       print "current analysis not found for rule\n";
     }
   }
   my $next_anal_id = &verify($rule,'next_analysis_id','OPTIONAL', '', 'next');
   my $next = _get_analysis($next_anal_id);
   if (!defined($next)) {
     print "next analysis not found for rule\n";
   }
   my $action = &verify($rule, 'action', 'OPTIONAL');
  
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
my $job_setup = $pipeline_setup->child('job_setup');
if($job_setup){
foreach my $job ($job_setup->children('job')) {
  if (ref($job)) {
   my $id = $job->attribute("id");
   my $process_id = &verify($job,'process_id','OPTIONAL','');
   my $queue_id = &verify($job,'queue_id','OPTIONAL','');
   my $retry_count = &verify($job,'retry_count','OPTIONAL','');
   my $analysis = &verify($job,'analysis_id','REQUIRED','');
   my $status = &verify($job,'status','OPTIONAL','NEW');

   my @input_objs;
   foreach my $input ($job->children('fixed_input')) {

     my $input_iohandler = _get_iohandler($input->child('input_iohandler_id')->value);
     if (!defined($input_iohandler)) {
       #$self->throw("Iohandler for input not found\n");
       print "Iohandler for input not found\n";
     }
     my $tag = &verify($input,'tag','OPTIONAL','input');
     my $name = &verify($input,'name','REQUIRED');

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

sub verify {
    my ($obj, $child,$required,$default, $attr_name) = @_;
    my %obj_attrs = $obj->attributes;
    $attr_name = $child unless(defined $attr_name); 
    
    if(defined $obj->child($child)){
        if(defined $obj->child($child)->value){
            return $obj->child($child)->value;
        }
#        else {
#            if($required =~/REQUIRED/){
#              defined $default && return $default;
#              die($obj->name . " is missing a value");
#            }
#        }
    }elsif(defined $attr_name && exists $obj_attrs{$attr_name}){
        return $obj_attrs{$attr_name};
    }else {
        if($required =~/REQUIRED/){
          defined $default && return $default;
          die($obj->name. " ".$obj->attribute('id'). " is missing a $child");
        }
    }
    return $default;
} 
    
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
 
