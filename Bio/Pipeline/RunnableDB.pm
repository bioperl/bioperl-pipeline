# Bioperl module for Bio::Pipeline::RunnableDB
#
# Adapted from Michele Clamp's EnsEMBL::Pipeline
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::Pipeline::RunnableDB

=head1 SYNOPSIS

# get a Bio::Pipeline::RunnableDB object somehow

  $runnabledb->fetch_input();
  $runnabledb->run();
  $runnabledb->output();
  $runnabledb->write_output(); #writes to DB

=head1 DESCRIPTION

parameters to new
-job    A Bio::Pipeline::Job(required), 

This object wraps Bio::Pipeline::Runnables to add
functionality for reading and writing to databases.  The appropriate
Bio::Job object must be passed for extraction
of appropriate parameters.

=head1 CONTACT

bioperl-l@bioperl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::Pipeline::RunnableDB;

use strict;
use Bio::Root::Root;
use Bio::DB::RandomAccessI;

use vars qw(@ISA);

@ISA = qw(Bio::Root::Root);



=head2 new

    Title   :   new
    Usage   :   $self->new(-JOB => $job,
			              );
    Function:   creates a Bio::Pipeline::RunnableDB object
    Returns :   A Bio::Pipeline::RunnableDB object
    Args    :   -job:   A Bio::Pipeline::Job (required), 
=cut

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($analysis,$inputs) = $self->_rearrange ([qw  (   
                                                                 ANALYSIS
                                                                 INPUTS
                                                                )],@args);
    
    $self->throw("No analysis provided to RunnableDB") unless defined($analysis);
    $self->throw("No inputs provided to RunnableDB") unless defined($inputs);
    $self->inputs($inputs);
    $self->analysis($analysis);
    $self->runnable($analysis->runnable);

    $self->{'_input_objs'}=[];
    $self->{'_data_types'}=[];
    $self->setup_runnable_params($analysis->parameters);

    return $self;
}

=head2 analysis

    Title   :   analysis
    Usage   :   $self->analysis($analysis);
    Function:   Gets or sets the stored Analusis object
    Returns :   Bio::Pipeline::Analysis object
    Args    :   Bio::Pipeline::Analysis object

=cut

sub analysis {
    my ($self, $analysis) = @_;
    
    if ($analysis)
    {
        $self->throw("Not a Bio::Pipeline::Analysis object")
            unless ($analysis->isa("Bio::Pipeline::Analysis"));
        $self->{'_analysis'} = $analysis;
    }
    return $self->{'_analysis'};
}

sub inputs {
    my ($self,$inputs) = @_;
    if($inputs) {
        $self->{'_inputs'} = $inputs;
    }
    return @{$self->{'_inputs'}};
}


sub setup_runnable_params {
    my ($self,$parameters) = @_;
    my @params = split("--",$parameters);
    shift @params; #first element is empty
    my %param;
    foreach my $param(@params){
      my @list = split(" ",$param);
      my $routine = shift @list;
      my $string = join " ",@list[0..$#list];
      $param{$routine} = $string;
    }
    #set the pamaters in the runnable
    my $runnable = $self->runnable;
    foreach my $routine (keys %param){
      $self->throw("Cannot call $routine using $runnable") unless $runnable->can($routine);
      $runnable->$routine($param{$routine});
    }
    return;
}


=head2 add_input_obj

    Title   :   add_input_obj
    Usage   :   
    Function:   
    Returns :   
    Args    :   

=cut

sub add_input_obj{
    my ($self,$input_obj) = @_;

    push (@{$self->{'_input_objs'}},$input_obj);

}

=head2 input_objs

    Title   :   input_objs
    Usage   :   
    Function:   
    Returns :   
    Args    :   

=cut

sub input_objs{
    my ($self) = @_;

    return @{$self->{'_input_objs'}};

}

=head2 output

    Title   :   output
    Usage   :   $self->output()
    Function:   
    Returns :   Array of Bio::FeaturePair
    Args    :   None

=cut

sub output {
    my ($self) = @_;
   
    $self->{'_output'} = [];
    
    
    if (defined $self->runnable->output){
	if(ref($self->runnable->output) eq "ARRAY"){
  		push @{$self->{'_output'}}, @{$self->runnable->output};
	}
	else {
  		push @{$self->{'_output'}}, $self->runnable->output;
	}
		
    }
    return @{$self->{'_output'}};
}

=head2 setup_runnable_inputs

    Title   :   setup_runnable_inputs
    Usage   :   $self->setup_runnable_inputs()
    Function:   Checks the inputs with the runnable data types and set the runnable inputs 
    Returns :   None 
    Args    :   None 

=cut

sub setup_runnable_inputs {
    my ($self,@input) = @_;
    my $runnable = $self->runnable;
    $runnable->can("datatypes") || $self->throw("Runnable $runnable has no sub datatypes implemeted.");
    my %r_datatypes = $runnable->datatypes;
    my @to_match;
    my %match_datatype={};

    if ($self->runnable->isa("Bio::Pipeline::Runnable::DataMonger")){
        my %hash;
        my $tag;
        foreach my $in(@input){
            $tag = $in->[1];
            my $in_obj = $in->[2];
            if($tag ne "no_tag"){
               $hash{$in->[0]} = $in_obj;
            }
        }
        #default to input method call for DataMonger is no tag specified.
        if($tag eq "no_tag"){
            $self->runnable->can('input') || $self->throw("Runnable $runnable cannot call $tag");
            $self->runnable->input(\%hash);
            return;
        }
        $self->runnable->can($tag) || $self->throw("Runnable $runnable cannot call $tag");
        $self->runnable->$tag(\%hash);
        return;
    }

DT: foreach my $in(@input){
      my $tag = $in->[1];
      my $in_obj = $in->[2];
      if($tag ne "no_tag"){
        $self->runnable->can($tag) || $self->throw("Runnable $runnable cannot call $tag");
        $self->runnable->$tag($in_obj);
        $match_datatype{$in_obj} = 1;
      }
      else {
        foreach my $r_key(keys %r_datatypes){
          if (ref($r_datatypes{$r_key}) eq "ARRAY"){
            foreach my $dt (@{$r_datatypes{$r_key}}){
              if ($self->match_data_type($in_obj,$dt)) {
                $match_datatype{$in_obj}=1;
                #set runnables inputs
                $self->runnable->can($r_key) || $self->throw("Runnable $runnable cannot call $r_key");
                $self->runnable->$r_key($in_obj);
                next DT;
              }

            }

          }
          else {
            if ($self->match_data_type($in_obj,$r_datatypes{$r_key})) {
              $match_datatype{$in_obj}=1;
              #set runnables inputs
              $self->runnable->can($r_key) || $self->throw("Runnable $runnable cannot call $r_key");
              $self->runnable->$r_key($in_obj);
              next DT;
            }
          }
          $self->throw("Job's inputs datatypes do not match runnable ".$self->runnable." datatypes.");
        }
      }
    }
}

=head2 match_data_type

    Title   :   match_data_type
    Usage   :   $self->match_data_type()
    Function:   checks an input whether it matches a data type object. It is handles inherited objects as matching 
                the parent.The input can be of type inherited from the type of the runnable but not the other
                way around 
    Returns :   None 
    Args    :   None 

=cut

sub match_data_type {
    my ($self,$input,$run_dt) = @_;
    my $in_dt = Bio::Pipeline::DataType->create_from_input($input);
    $run_dt->isa("Bio::Pipeline::DataType") || $self->throw("Need a Bio::Pipeline::DataType to check");

    #have to do this check cuz the isa call will barf it its not an valid object
    if ((ref($input) ne "SCALAR") && (ref($input) ne "ARRAY") && (ref($input) ne "HASH")){
      if ($input->isa($run_dt->object_type)){ 
        return 1;
      }
      else {
        return 0;
      }
    }
    elsif(ref($input) eq "ARRAY"){
        if($run_dt->ref_type eq "ARRAY"){
          foreach my $in (@{$input}){
            if(!$in->isa($run_dt->object_type)){
                return 0;
            }
          }
          return 1;
        }
        else {return 0;}
    }
    elsif (($in_dt->object_type eq $run_dt->object_type) && ($in_dt->ref_type eq $run_dt->ref_type)){
      return 1;
    }
    else {
      return 0;
    }
}

=head2 run

    Title   :   run
    Usage   :   $self->run();
    Function:   Runs Bio::Pipeline::Runnable::xxxx->run()
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;
    
    my $runnable = $self->runnable; 
    $runnable->analysis($self->analysis);
    $self->throw("Runnable module not set") unless ($runnable);
    $self->throw("Inputs not fetched") unless ($self->input_objs());
    $runnable->run();
}


=head2 runnable

    Title   :   runnable
    Usage   :   $self->runnable($arg)
    Function:   Sets a runnable for this RunnableDB
    Returns :   Bio::Pipeline::RunnableI
    Args    :   Bio::Pipeline::RunnableI

=cut

sub runnable {
    my ($self,$arg) = @_;

    if (!defined($self->{'_runnable'})) {
       $self->{'_runnable'} = ();
    }
  
    if (defined($arg)) {
      if($self->analysis->runnable->isa("Bio::Pipeline::Runnable::DataMonger")){
          my $dm_adaptor = $self->analysis->adaptor->db->get_DataMongerAdaptor;
          my $runnable = $dm_adaptor->fetch_by_analysis($self->analysis);
          $runnable->next_analysis($self->analysis->adaptor->fetch_next_analysis($self->analysis));
          $self->{'_runnable'} = $runnable;
      }
      else {

        #create empty runnable
        $arg =~ s/\::/\//g;
        require "${arg}.pm";
        $arg =~ s/\//\::/g;

        my $runnable = "${arg}"->new();
	      $self->{'_runnable'}=$runnable;
      }

	}
    return $self->{'_runnable'};  
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Writes output data to db
    Returns :   array of repeats (with start and end)
    Args    :   none

=cut

sub write_output {
    my($self) = @_;

    my @output = $self->output();
    my @inputs = $self->inputs;
    return () unless scalar(@output);    
    my @output_ids = $self->analysis->output_handler->write_output(\@inputs,\@output);

    return @output_ids;
}

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   
    Returns :   
    Args    :   

=cut

sub fetch_input {
    my($self) = @_;
    my @inputs = $self->inputs;
    my $count = 0;
    my @input_table;
    foreach my $input (@inputs){

        print "fetching nbr $count\n";
        $count++;
        #added this check to see where we get an array ref as one element of the array of inputs
        #currently this only happens for WAITFORALL_UPDATE where all the output_ids must be fetched
        #and pushed into a array to be passed as input the the runnable.
        if(ref($input) eq "ARRAY"){
            my @input_objs;
            foreach my $sub (@{$input}){
              push @input_objs, $sub->fetch;
            }
            $self->add_input_obj(\@input_objs);
            if($input->tag){
              push @input_table, [$input->name,$input->tag,\@input_objs];        
            }
            else {
              push @input_table, [$input->name,'no_tag',\@input_objs];
            }

        }
        else {
          my $input_obj = $input->fetch;
          my $datatype =  Bio::Pipeline::DataType->create_from_input($input_obj);
          $self->add_input_obj($input_obj);
          if($input->tag){
            push @input_table, [$input->name,$input->tag,$input_obj];        
          }
          else {
            push @input_table, [$input->name,'no_tag',$input_obj];
          }

        }
    }

    $self->setup_runnable_inputs(@input_table);
    
    return $self->input_objs;
}

1;
