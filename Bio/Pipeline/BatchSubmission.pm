# Pipeline module for Bio::Pipeline::BatchSubmission 
#
# Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::BatchSubmission
# originally written by Laura Clarke <lec@sanger.ac.uk>
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::Pipeline::BatchSubmission

=head1 SYNOPSIS

   #There are two ways to create a BatchSubmission modules
   #Either you can call new on this top-level module
   #as below, and the batch module will be specified by the BATCH_MOD  from PipeConf.pm
   #variable, or you can call new directly on one of the BatchSubmission 
   #modules such as Bio::Pipeline::LSF or Bio::Pipeline::PBS

   my $batchsub = Bio::Pipeline::BatchSubmission->new(
						      -dbobj => $dbobj,
						      -stdout => $stdout,
						      -stderr => $stderr,
						      -parameters => $pars,
						      -pre_exec => $pre,
						      -command => $command,
						      -queue => $queue,
						      -jobname => $jobn,
						      -nodes => $nodes,
  						      -priority =>$priority
						      );

=head1 DESCRIPTION

This module is a generic representation of different Batch Submission
systems, which allow distribution of work across a cluster. The logic
was abstracted in this module to allow users to write different modules
for different systems. Specific modules have been written for PBS and LSF
and are stored in the BatchSubmission directory.

The module's getset deal with the STDOUT and STDERR files required, the 
actual command to be issued as well as the pre-execution command to use as 
test, parameters to be passed onto the submission system, the queue to send 
the job to, and the name of the job.

=head1 AUTHOR

Based on the EnsEMBL module Bio::EnsEMBL::Pipeline::BatchSubmission
originally written by Laura Clarke <lec@sanger.ac.uk>

# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
Cared for by the Fugu Informatics team (fuguteam@fugu-sg.org)

=head1 CONTACT

Fugu Informatics team: fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

# Let the code begin...


package Bio::Pipeline::BatchSubmission;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;

use Bio::Pipeline::PipeConf qw(BATCH_MOD
                               BATCH_PARAM);


@ISA = qw(Bio::Root::Root);

=head2 new

  Title   : new
  Usage   : my $batchsub = Bio::Pipeline::BatchSubmission->new(
                  -dbobj => $dbobj,
                  -stdout => $stdout,
                  -stderr => $stderr,
                  -parameters => $pars,
                  -pre_exec => $pre,
                  -command => $command,
                  -queue => $queue,
                  -jobname => $jobn,
                  -nodes => $nodes,
                  -priority =>$priority
                  );
  Function: Constructor for BatchSubmission objet
  Returns : L<Bio::Pipeline::BatchSubmission>
  Args    : -dbobj  the dbadaptor object to the pipeline database 
            -stdout the stdout file to which to pipe STDOUT
            -stderr the stderr file to which to pipe STDERR
            -parameters any parameters to be passed to the BatchSubmission object
            -pre_exec any pre_exec commands to be passed to the load sharing software
            -command the command name for submitting jobs
            -queue the queue name to which to submit jobs to
            -jobname  the name of the job
            -nodes the array ref node ids to limit submission to

=cut

sub new{
    my ($caller, @args) = @_;
    my $class = ref($caller) || $caller;

    if ($class =~ /Bio::Pipeline::BatchSubmission::(\S+)/){
        my ($self) = $class->SUPER::new(@args);
        my ($dbobj,$stdout,$stderr,$parameters,$pre_exec,$command,$queue,$jobname,$nodes,$priority) =  
                       $self->_rearrange([qw(   DBOBJ
                                                STDOUT
                                                STDERR
                                                PARAMETERS
                                                PRE_EXEC
                                                COMMAND
                                                QUEUE
                                                JOBNAME
                                                NODES
						PRIORITY
                                            )],@args);

        $self->throw("BatchSubmission object requires a dbobj") unless $dbobj;

        $self->dbobj($dbobj);

        if(defined($stdout)){
            $self->stdout_file($stdout);
        }
        if(defined($stderr)){
            $self->stderr_file($stderr);
        }
        if(defined($parameters)){
            $self->parameters($parameters);
        }
        elsif($BATCH_PARAM){
            $self->parameters($BATCH_PARAM);
        }
        if(defined($pre_exec)){
            $self->pre_exec($pre_exec);
        }
        if(defined($command)){
            $self->command($command);
        }
        if(defined($queue)){
            $self->queue($queue);
        }
        if (defined($jobname)){
            $self->jobname($jobname);
        }
        if (defined($nodes)){
            $self->nodes($nodes);
        }
        if (defined($priority)){
   	    $self->priority($priority);
        }

        @{$self->{'_jobs'}}=();
        
        return $self;

    }else{
        my $module = "Bio/Pipeline/BatchSubmission/$BATCH_MOD.pm";
        eval {
            require $module;
        };
        if ($@) { 
            print STDERR "Module $module can't be found.\nException $@";
            return;
        }

        return "Bio::Pipeline::BatchSubmission::$BATCH_MOD"->new(@args);
    }
}

##################
#get/sets        #
##################

=head2 add_job

  Title    : add_job
  Function : adds a job  
  Example  : $bs->add_job($job);
  Returns  : 
  Args     : L<Bio::Pipeline::Job>

=cut

sub add_job{
    my ($self,$job) = @_;
    
    $self->throw("Job missing in BatchSubmission->add_job") unless $job;
    $self->throw("Improper job object passed") unless $job->isa("Bio::Pipeline::Job");

    push (@{$self->{'_jobs'}}, $job);
}

=head2 get_jobs

  Title    : get_jobs
  Function : returns the jobs in the BS object
  Example  : $bs->get_jobs();
  Returns  : An array of L<Bio::Pipeline::Job>
  Args     :

=cut

sub get_jobs{
    my ($self) = @_;

    $self->throw("BatchSubmmission object does not seem to contain any jobs.") unless @{$self->{'_jobs'}};

    return @{$self->{'_jobs'}};
}

=head2 batched_jobs

  Title    : batched_jobs
  Function : returns the number of jobs in the BS object 
  Example  : $bs->batched_jobs();
  Returns  : an int
  Args     :

=cut

sub batched_jobs{
    my ($self) = @_;
    return scalar(@{$self->{'_jobs'}});
}

=head2 empty_batch

  Title    : empty_batch
  Function : flushes the list of jobs in the object 
  Example  : $bs->empty_batch
  Returns  : 
  Args     :

=cut

sub empty_batch{
    my ($self) = @_;
    @{$self->{'_jobs'}} = ();
}

=head2 dbobj

  Title    : dbobj
  Function : get/set for the pipeline database object 
  Example  : $bs->dbobj($dbadaptor)
  Returns  : L<Bio::Pipeline::SQL::DBAdaptor> 
  Args     : L<Bio::Pipeline::SQL::DBAdaptor>

=cut

sub dbobj{
    my ($self,$arg) = @_;
    
    if (defined $arg){
        $self->throw("Need a Bio::Pipeline::DBAdaptor object") unless $arg->isa("Bio::Pipeline::SQL::DBAdaptor");
        $self->{'_dbobj'} = $arg; 
    }

    return $self->{'_dbobj'};
}

=head2 stdout_file

  Title    : stdout_file
  Function : get/set for the file to pipe STDOUT to
  Example  : $bs->stdout_file('/tmp/1.out');
  Returns  : a string
  Args     : a string

=cut

sub stdout_file{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_stdout'} = $arg;
   }

   return $self->{'_stdout'};
}

=head2 stderr_file

  Title    : stderr_file
  Function : get/set for the file to pipe STDERR to
  Example  : $bs->stderr_file('/tmp/1.err');
  Returns  : a string
  Args     : a string

=cut

sub stderr_file{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_stderr'} = $arg;
   }

   return $self->{'_stderr'};
}

=head2 parameters

  Title    : parameters
  Function : get/set for parameters to be passed to the sub command 
  Example  : $bs->parameters()
  Returns  : String
  Args     : String

=cut

sub parameters{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_parameters'} = $arg;
   }

   return $self->{'_parameters'};
}

=head2 pre_exec

  Title    : pre_exec
  Function : get/set for the pre_exec command 
  Example  : $bs->pre_exec()
  Returns  : string
  Args     : string

=cut

sub pre_exec{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_pre_exec'} = $arg;
   }

   return $self->{'_pre_exec'};
}

=head2 command

  Title    : command
  Function : get/set for command
  Example  : $bs->command
  Returns  : string
  Args     : string

=cut

sub command{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_command'} = $arg;
   }

   return $self->{'_command'};
}

=head2 runner_path

  Title    : runner_path
  Function : get/set for runner_path 
  Example  : $bs->runner_path('/pathto/runner.pl');
  Returns  : string
  Args     : string

=cut

sub runner_path{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_runner_path'} = $arg;
   }

   return $self->{'_runner_path'};
}

=head2 queue

  Title    : queue
  Function : get/set for queue id
  Example  : $bs->queue('normal4');
  Returns  : string
  Args     : string

=cut

sub queue{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_queue'} = $arg;
   }

   return $self->{'_queue'};
}

=head2 jobname

  Title    : jobname
  Function : get/set jobname
  Example  : $bs->jobname()
  Returns  : String
  Args     : String

=cut

sub jobname{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_jobname'} = $arg;
   }

   return $self->{'_jobname'};
}

=head2 nodes

  Title    : nodes
  Function : get/set for nodes
  Example  : $bs->nodes
  Returns  : list of node ids
  Args     :

=cut

sub nodes{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_nodes'} = $arg;
   }

   return $self->{'_nodes'};
}

=head2 priority 

  Title    : priority 
  Function : get/set for priority 
  Example  : $bs->priority
  Returns  : priority 
  Args     :

=cut

sub  priority{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_priority'} = $arg;
   }

   return $self->{'_priority'};
}


#############
#run methods#
#############

=head2 construct_runner_param

  Title    : construct_runner_param
  Function : method that constructs the parameters to runner.pl
  Example  : $command = $bs->construct_runner_paam
  Returns  : a string
  Args     : a string

=cut

sub construct_runner_param {
  my ($self,$runner) = @_;
  my $dbobj = $self->dbobj;

  $runner .= defined $dbobj->dbname ? " -dbname ".$dbobj->dbname : "";
  $runner .= defined $dbobj->host ? " -host ".$dbobj->host : "";
  $runner .= defined $dbobj->port ? " -port ".$dbobj->port: "";
  $runner .= " -pass ".$dbobj->password if $dbobj->password;
  $runner .= defined $dbobj->username ? " -dbuser ".$dbobj->username: "";
  return $runner;
}

=head2 construct_command_line

  Title    : construct_command_line
  Function : Abstract method that constructs the command line for 
             submitting jobs
  Example  : $command = $bs->construct_command_line;
  Returns  : a string
  Args     : a string

=cut

sub construct_command_line{
  my($self) = @_;

  $self->throw("Sorry, you cannot call this method from a generic BatchSumission Object");

}


#implemeted submit_batch should implement the action parameter to pass to runner.pl which
#specifies the action to that the job undergoes according to the rule table

=head2 submit_batch

  Title    : submit_batch
  Function : abstract method for doing the job submissions
  Example  : $bs->submit_batch
  Returns  : true if successful
  Args     : 

=cut

sub submit_batch{

  my ($self,$action)= @_;
  
  $self->throw("Sorry, you cannot call this method from a generic BatchSumission Object");

}

=head2 kill_jobs

  Title    : kill_jobs
  Function : kills jobs in the queue and updates the job status as 'KILLED'
  Example  : $command = $bs->kill_jobs;
  Returns  : 
  Args     : a list of queue ids

=cut

sub kill_jobs {
  my ($self) = @_;
  $self->throw_not_implemented();
}

sub get_host_name{
    my ($queue_id) = @_;
    my $module = "Bio/Pipeline/BatchSubmission/$BATCH_MOD.pm";
    eval {
      require $module;
   };
   if ($@) {
    print STDERR "Module $module can't be found.\nException $@";
    return;
  }
  my $mod = "Bio::Pipeline::BatchSubmission::$BATCH_MOD";
  return $mod->get_host_name($queue_id);
}

sub sort_by_queue {
  my ($self,@jobs) = @_;
  my %hash;
  foreach my $j(@jobs) {
   if(!$j->analysis->queue){
    push @{$hash{$self->queue}} ,$j;
   }
   else {
    push @{$hash{$j->analysis->queue}},$j;
   }
  }
  return \%hash;
}
1;
