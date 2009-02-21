#
# BioPerl module for Bio::Pipeline::XMLImporter
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#

=head1 NAME

Bio::Pipeline::XMLImporter

=head1 SYNOPSIS

  use Bio::Pipeline::XMLImporter;
  my $importer = Bio::Pipeline::XMLImporter->new (
                                                  -dbhost=>$DBHOST,
                                                  -dbname=>$DBNAME,
                                                  -dbuser=>$DBUSER,
                                                  -dbpass=>$DBPASS,
                                                  -schema=>$SCHEMA,
                                                  -xml   =>$XML);
  my $loaded = $importer->run($XMLFORCE);

=head1 DESCRIPTION

Module for importing pipeline configuration in xml to biopipe.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.open-bio.org/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut


package Bio::Pipeline::XMLImporter;
use strict;

use Bio::Pipeline::Analysis;
use Bio::Pipeline::Job;
use Bio::Pipeline::Input;
use Bio::Pipeline::IOHandler;
use Bio::Pipeline::DataHandler;
use Bio::Pipeline::Method;
use Bio::Pipeline::Argument;
use Bio::Pipeline::Rule;
use Bio::Pipeline::NodeGroup;
use Bio::Pipeline::Node;
use Bio::Pipeline::Runnable::DataMonger;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::Transformer;
use ExtUtils::MakeMaker;
use Bio::Pipeline::AbstractXMLImporter;
use vars qw(%global);
our @ISA = qw(Bio::Pipeline::AbstractXMLImporter);

=head2 new

  Title   : new
  Usage   :my $importer = Bio::Pipeline::XMLImporter->new (
                                                -dbhost=>$DBHOST,
                                                -dbname=>$DBNAME,
                                                -dbuser=>$DBUSER,
                                                -dbpass=>$DBPASS,
                                                -schema=>$SCHEMA,
                                                -xml   =>$XML);  
  Function: constructor for XMLImporter object 
  Returns : a new XMLImporter object
  Args    : db parameters
	    xml the xml template file

=cut

=head2 run

  Title   : run
  Usage   : $self->run();
  Function: load the xml template up 
  Returns : 1 if successful
  Args    : $FORCE 1/0 whether to prompt for dropping database

=cut

sub _parse_global{
    my ($self, $pipeline_setup)=@_;
    $pipeline_setup->child('global') or return;
    %global = $pipeline_setup->child('global')->attributes;
    foreach my $key (keys %global){$global{$key} = &set_global($global{$key});}
}

sub run{
    my ($self, $FORCE) = @_;
    my $dba=$self->_prepare_dba($FORCE);
    my $xso1 = $self->_prepare_xso;
my @iohandler_objs;
my $method_id = 1;
############################################
#Load DBAdaptor and IOHandler information
############################################
print "Doing DBAdaptor and IOHandler setup\n";

my $pipeline_setup  = $xso1->child('pipeline_setup') || die("Pipeline template missing <pipeline_setup>\n Please provide a valid one");

#setting global hash
$self->_parse_global($pipeline_setup);

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
       $adaptor_type = &verify($iohandler,'adaptor_type','','','');
   }elsif(exists $adaptor_attrs{'type'}){
       $adaptor_type = $adaptor_attrs{'type'};
   }else{
       $adaptor_type = "DB";
   }

   my $adaptor_id;
   if(defined $iohandler->child('adaptor_id') ){
       $adaptor_id = &verify($iohandler,'adaptor_id','','','');
   }elsif(exists $adaptor_attrs{'id'}){
       $adaptor_id = $adaptor_attrs{'id'};
   }
   
  my $iotype     = &verify($iohandler,'iohandler_type','REQUIRED', '', 'type');
  
  my @method = $iohandler->children('method');

  foreach my $method (@method) {
    next unless ref $method;
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
    my $datahandler_obj = Bio::Pipeline::DataHandler->new(
        -dbid => $method_id,
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
          my $file_path = &verify($streamadaptor,'file_path');
          my $file_suffix = &verify($streamadaptor,'file_suffix');
          my $iohandler_obj = Bio::Pipeline::IOHandler->new_ioh_stream (
            -dbid=>$ioid,
            -type=>$iotype,
            -module=>$module,
            -file_path=>$file_path,
            -file_suffix=>$file_suffix,
            -datahandlers => \@datahandler_objs);

          push @iohandler_objs, $iohandler_obj;
        }
     }
   }
  elsif($adaptor_type eq 'CHAIN'){
    my $iohandler_obj = Bio::Pipeline::IOHandler->new_ioh_chain(-dbid=>$ioid,-type=>$iotype);
    push @iohandler_objs,$iohandler_obj;
  }
}

print "Doing Transformers..\n";
my @pipeline_transformer_objs;
$iohandler_setup->children('transformer') || goto PIPELINE_FLOW_SETUP;
foreach my $transformer ($iohandler_setup->children('transformer')){
       next unless (defined $transformer);
       next unless ref $transformer;
       my $id = &verify_attr($transformer, 'id', 1);
       my $module = &verify($transformer, 'module');
       my @method_objs;
       foreach my $method ($transformer->children('method')){
           next unless(defined $method);
           next unless ref $method;
           my $method_name = &verify($method, 'name', 1);
           my $method_rank = &verify($method, 'rank', 0);
           my @method_arguments;
           if(defined $method->children('argument')){
             foreach my $argument ($method->children('argument')){
               next unless(defined $argument);
               next unless ref $argument;
               my $argument_tag = &verify($argument, 'tag', 0);
               my $argument_value = &verify($argument, 'value', 1);
               my $argument_rank = &verify($argument, 'rank', 0);
               my $argument_type = &verify($argument, 'type', 0);
               my $argument_obj = new Bio::Pipeline::Argument(
                  -tag => $argument_tag,
                  -value => $argument_value,
                  -rank => $argument_rank,
                  -type => $argument_type
                  );
               push @method_arguments, $argument_obj;
            }
               
           }
           my $method_obj = new Bio::Pipeline::Method(
               -name => $method_name,
               -rank => $method_rank,
               -argument => \@method_arguments
               );
           
           push @method_objs, $method_obj;
           
       }
       my $transformer_obj = new Bio::Pipeline::Transformer(
         -dbID => $id,
         -module => $module,
         -method => \@method_objs
       );
       push @pipeline_transformer_objs, $transformer_obj;
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



my @analysis_objs;
print "Doing Analysis..\n";
foreach my $analysis ($xso1->child('pipeline_setup')->child('pipeline_flow_setup')->children('analysis')) {

    my $analysis_obj;
    my $datamonger = $analysis->child('data_monger');
    if (defined $datamonger) {
        my @datamonger_iohs;
        $analysis_obj = Bio::Pipeline::Analysis->new(
            -id => $analysis->attribute('id'),
            -runnable => 'Bio::Pipeline::Runnable::DataMonger',
            -logic_name => 'DataMonger',
            program => 'DataMonger');
        my @initial_input_objs; 
        my $input_present_flag = 0;
    	foreach my $input ($datamonger->children('input')){
         if (ref ($input)) {
           $input_present_flag = 1;
           my $name = &verify($input,'name','REQUIRED');
           my $input_iohandler_id = &verify($input,'iohandler','OPTIONAL','0');

           my $tag = &verify($input,'tag','OPTIONAL','input');
           my $input_iohandler_obj = $self->_get_iohandler($input_iohandler_id,@iohandler_objs) if $input_iohandler_id;

           push @datamonger_iohs, $input_iohandler_obj if $input_iohandler_obj;

           my $initial_input_obj = Bio::Pipeline::Input->new(
            -name => $name,
            -tag => $tag,
            -job_id => 1,
            -input_handler => $input_iohandler_obj);
           push @initial_input_objs, $initial_input_obj;
         }
        }
        if ($input_present_flag) {
          $self->_create_initial_input_and_job($analysis_obj,@initial_input_objs); 
        }
        my $datamonger_obj = Bio::Pipeline::Runnable::DataMonger->new();

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
    	my $analysis_parameters = $analysis->child('analysis_parameters');
    	my $runnable_parameters = $analysis->child('runnable_parameters');
    	my $logic_name = $analysis->child('logic_name');
      my $queue = $analysis->child('queue');

   	if(defined($logic_name)){
       		$analysis_obj->logic_name(&set_global($logic_name->value));
   	}
    if(defined($queue)){
          $analysis_obj->queue(&set_global($queue->value));
    }
   	if (defined($program)){
      		$analysis_obj->program(&set_global($program->value));
   	}
   	if (defined($program_file)){
      		$analysis_obj->program_file(&set_global($program_file->value));
   	}
   	if (defined($db)){
      		$analysis_obj->db(&set_global($db->value));
   	}
   	if (defined($db_file)){
      		$analysis_obj->db_file(&set_global($db_file->value));
   	}
   	if (defined($analysis_parameters)){
      		$analysis_obj->analysis_parameters(&set_global($analysis_parameters->value));
   	}
   	if (defined($runnable_parameters)){
      		$analysis_obj->runnable_parameters(&set_global($runnable_parameters->value));
   	}
    }
   my $nodegroup_id = $analysis->child('nodegroup_id');
   if (defined($nodegroup_id)){
      my $node_group = $self->_get_nodegroup(\@nodegroup_objs, $nodegroup_id->value);
      if (!defined($node_group)) {
#        print "node_group for analysis not found\n";
      }
      else { $analysis_obj->node_group($node_group); }
   }
   my @ioh;

   foreach my $input_iohandler ($analysis->child('input_iohandler')) {
     if (defined($input_iohandler)){
         my $input_iohandler_obj = $self->_get_iohandler($input_iohandler->attribute("id"),@iohandler_objs);
         if(!defined($input_iohandler_obj)){
            print "input iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @transformer_objs;
            foreach my $transformer ($input_iohandler->child('transformer')) {
              my $transformer_obj = $self->_get_transformer(\@pipeline_transformer_objs, $transformer->attribute("id")); 
              if(defined($transformer_obj)){
                 my $rank = &verify($transformer,'rank',0,1); 
                 $transformer_obj->rank($rank);
                 push @transformer_objs, $transformer_obj;
              } else { print "transformer for analysis  not found\n"; }
            }
            $input_iohandler_obj->transformers(\@transformer_objs);
            $input_iohandler_obj->type('INPUT');;
            push @ioh, $input_iohandler_obj;
         }
     }
   }
   foreach my $output_iohandler ($analysis->child('output_iohandler')) {
     if (defined($output_iohandler)){
         my $output_iohandler_obj = $self->_get_iohandler($output_iohandler->attribute("id"),@iohandler_objs);
         if(!defined($output_iohandler_obj)){
            print "output iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @transformer_objs;
            foreach my $transformer ($output_iohandler->child('transformer')) {
              my $transformer_obj = $self->_get_transformer(\@pipeline_transformer_objs, $transformer->attribute("id")); 
              if(defined($transformer_obj)){
                 my $rank = &verify($transformer,'rank',0,1); 
                 $transformer_obj->rank($rank);
                 push @transformer_objs, $transformer_obj;
              } else { print "transformer for analysis  not found\n"; }
            }
            $output_iohandler_obj->transformers(\@transformer_objs) if $#transformer_objs >=0;
            $output_iohandler_obj->type('OUTPUT');
            push @ioh, $output_iohandler_obj;
         }
     }
   }

    foreach my $map ($analysis->children('input_iohandler_mapping')){
        if (ref($map)){
          my $prev_iohandler_id = $map->child('prev_analysis_iohandler_id');
          my $current_iohandler_id = $map->child('current_analysis_iohandler_id');
          if ($current_iohandler_id){
                  my $current_iohandler = $self->_get_iohandler( &set_global($current_iohandler_id->value),@iohandler_objs);
                  if (!defined($current_iohandler)) {
                     print "current input iohandler for analysis not found\n";
                  }
#                  push @ioh, $current_iohandler;
                  #store to iohandler_map table
                  my $prev = &set_global($prev_iohandler_id->value) if $prev_iohandler_id;
                  $dba->get_IOHandlerAdaptor->store_map_ioh($analysis_obj->dbID,$prev,&set_global($current_iohandler_id->value));
          }
        }
   }

   foreach my $new_input_iohandler ($analysis->child('new_input_iohandler')) {
     if (defined($new_input_iohandler)){
         my $new_input_iohandler_obj = $self->_get_iohandler($new_input_iohandler->attribute("id"),@iohandler_objs);
         if(!defined($new_input_iohandler_obj)){
            print "new_input iohandler for analysis $analysis->dbID not found\n";
         } else {
            my @transformer_objs;
            foreach my $transformer ($new_input_iohandler->child('transformer')) {
              my $transformer_obj = $self->_get_transformer(\@pipeline_transformer_objs, $transformer->attribute("id"));
              if(defined($transformer_obj)){
                 $transformer_obj->rank($transformer->attribute("rank"));
                 push @transformer_objs, $transformer_obj;
              } else { print "transformer for analysis  not found\n"; }
            }
            $new_input_iohandler_obj->transformers(\@transformer_objs);
            $new_input_iohandler_obj->type('NEW_INPUT');
            push @ioh, $new_input_iohandler_obj;
         }
     }
   }
   $analysis_obj->iohandler(\@ioh);
   push @analysis_objs, $analysis_obj;
 }

print "Doing Rules\n";
my @rule_objs =$self->_parse_rules($pipeline_flow_setup, \@analysis_objs); 
#store first before fetching job ids as I need the iohandlers in the db

foreach my $iohandler (@iohandler_objs) {
  $dba->get_IOHandlerAdaptor->store_if_needed($iohandler);
}

print "Doing Job Setup...\n";
my @job_objs=$self->_parse_jobs($pipeline_setup, \@iohandler_objs);
##########################################################################
# now the nicest part .. the actual storing.. need to store only 4 objects, 
# iohandler, analysis, job and rule .. these objects will inturn store all the objects that they contain..
#########################################################################
# map{$dba->get_TransformerAdaptor->store($_)}@pipeline_transformer_objs;
$dba->get_TransformerAdaptor->store(\@pipeline_transformer_objs);
map{$dba->get_AnalysisAdaptor->store($_)}@analysis_objs;
map{$dba->get_JobAdaptor->store($_)}@job_objs;
map{$dba->get_RuleAdaptor->store($_)}@rule_objs;
$self->debug("Loading of pipeline completed\n");
return 1;
} # End of run
sub _parse_rules {
    my ($self, $pipeline_flow_setup, $analysis_objs)=@_;
    my @rule_objs;
    for my $rule_group($pipeline_flow_setup->children('rule_group')) {
        next unless $rule_group;
        foreach my $rule($rule_group->children('rule')){
            next unless ref($rule);
            my $anal_id = &verify($rule,'current_analysis_id','OPTIONAL', '', 'current');
            my $current = $self->_get_analysis($analysis_objs, $anal_id);
            my $next_anal_id = &verify($rule,'next_analysis_id','OPTIONAL', '', 'next');
            my $next = $self->_get_analysis($analysis_objs, $next_anal_id);
            print "next analysis not found for rule\n" unless defined $next;
            my $action = &verify($rule, 'action', 'OPTIONAL');
            my $rule_obj = Bio::Pipeline::Rule->new(
                -current=> $current,
                -next => $next,
                -rule_group_id=>$rule_group->attribute('id'),
                -action => $action);
            push @rule_objs, $rule_obj;
        }
    }
    return @rule_objs;
}

sub _parse_jobs {
    my ($self, $pipeline_setup, $iohandler_objs)=@_;
    my $job_setup = $pipeline_setup->child('job_setup');
    $job_setup or return ();
    my @job_objs;
    for my $job($job_setup->children('job')){
        next unless (ref $job);
        my $id=$job->attribute('id');
        my $process_id=&verify($job,'process_id','OPTIONAL','');
        my $queue_id = &verify($job,'queue_id','OPTIONAL','');
        my $retry_count = &verify($job,'retry_count','OPTIONAL','');
        my $analysis = &verify($job,'analysis_id','REQUIRED','');
        my $status = &verify($job,'status','OPTIONAL','NEW');
        my @input_objs;
        for my $input ($job->children('fixed_input')) {
            my $input_iohandler = $self->_get_iohandler(&set_global($input->child('input_iohandler_id')->value),@$iohandler_objs );
            if (!defined($input_iohandler)) {
                print "Iohandler for input not found\n";
            }
            my $tag = &verify($input,'tag','OPTIONAL','input');
            my $name = &verify($input,'name','REQUIRED');
            my $input_obj = Bio::Pipeline::Input->new(
                -name => $name,
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
            -adaptor => $self->dba->get_JobAdaptor,
            -inputs => \@input_objs);
        push @job_objs, $job_obj;
    }
    return @job_objs;
}

####################################################################
#Utility Methods
####################################################################

sub verify {
    my ($obj, $child,$required,$default, $attr_name) = @_;
    my %obj_attrs = $obj->attributes;
    $attr_name = $child unless(defined $attr_name); 
    
    if(defined $obj->child($child)){
        if(defined $obj->child($child)->value){
            return set_global($obj->child($child)->value);
        }
#        else {
#            if($required =~/REQUIRED/){
#              defined $default && return $default;
#              die($obj->name . " is missing a value");
#            }
#        }
    }elsif(defined $attr_name && exists $obj_attrs{$attr_name}){
        return set_global($obj_attrs{$attr_name});
    }else {
        if($required =~/REQUIRED/){
          defined $default && return $default;
          die($obj->name. " ".$obj->attribute('id'). " is missing a $child");
        }
    }
    return set_global($default);
} 

sub set_global {
  my ($string) = @_;
  while($string=~/\$(\w+)/){
    my $var = $global{$1};
    warn("\nvariable \$$1 doesn't exist. Pls check that you have it defined in the <global> tag.") if (!defined $var);    
    $string=~s/\$$1/$var/;
  }
  return $string;
}

sub verify_attr{
    my $obj=shift;
    my ($attr_name, $required, $default) = @_;
    my $obj_name = $obj->name;
#    print "$obj_name\t$attr_name\n";

    my %obj_attrs;
#    eval{
        %obj_attrs = $obj->attributes;
#    };
#    if($@){$self->throw($@);}

    if(defined $attr_name && exists $obj_attrs{$attr_name}){
#        print $obj_attrs{$attr_name} . "\n";
        return $obj_attrs{$attr_name};
    }elsif(defined $required && $required){
        $default || return $default;
        die($obj->name . " ". $obj->attribute('id') . " is missing an attr as " . $attr_name);
    }
}

sub _create_initial_input_and_job {
  my ($self, $analysis_obj, @initial_input_objs)= @_;
  #assume first job has rule_group_id 1
  my $job_obj = Bio::Pipeline::Job->new(-analysis => $analysis_obj,
                                         -rule_group_id=>1,
                                         -adaptor => $self->dba->get_JobAdaptor,
                                         -inputs => \@initial_input_objs);
  $self->dba->get_JobAdaptor->store($job_obj);
}

sub _get_transformer {
    my ($self, $pipeline_transformer_objs, $id) = @_;
    return $self->_search_array_by($pipeline_transformer_objs, 'dbID', $id);
}


sub _get_analysis {
    my ($self, $analysis_objs, $id) = @_;
    return $self->_search_array_by($analysis_objs, 'dbID', $id);
}

sub _get_iohandler {
    my ($self,$id, @iohandler_objs) = @_;

    foreach my $iohandler(@iohandler_objs) {
        if ($iohandler->dbID == $id) {
            my $new;
            %{$new} = %{$iohandler};
            bless $new, ref $iohandler;
            return $new;
        }
    }
    return undef;
}

sub _get_nodegroup {
    my ($self, $nodegroup_objs, $id) = @_;
    foreach my $nodegroup(@{$nodegroup_objs}) {
        if ($nodegroup->id == $id) {
            return $nodegroup;
        }
    }
    return undef;
}

sub _search_array_by{
    my ($self, $array, $field, $value) = @_;
    foreach(@{$array}){
        if($_->$field == $value){
            my $new;
            %{$new} = %{$_};
            bless $new, ref $_;
            return $new;
        }
    }
    return undef;
}

1;
