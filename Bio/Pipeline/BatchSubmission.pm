# BioPerl runnable for Bio::Pipeline::BatchSubmission 

# Written by FuguI team (fugui@fugu-sg.org)
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::Pipeline::BatchSubmission

=head1 SYNOPSIS

   #There are two ways to create a BatchSubmission modules
   #Either you can call new on this top-level module
   #as below, and the batch module will be specified by the BATCH_MOD 
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
						      -nodes => $nodes
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

=head1 CONTACT

FuguI team Singapore: fugui@fugu-sg.org

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

sub new{
    my ($caller, @args) = @_;
    my $class = ref($caller) || $caller;

    if ($class =~ /Bio::Pipeline::BatchSubmission::(\S+)/){
        my ($self) = $class->SUPER::new(@args);
        my ($dbobj,$stdout,$stderr,$parameters,$pre_exec,$command,$queue,$jobname,$nodes) =  
                       $self->_rearrange([qw(   DBOBJ
                                                STDOUT
                                                STDERR
                                                PARAMETERS
                                                PRE_EXEC
                                                COMMAND
                                                QUEUE
                                                JOBNAME
                                                NODES
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

sub add_job{
    my ($self,$job) = @_;

    $self->throw("Job missing in BatchSubmission->add_job") unless $job;

    push (@{$self->{'_jobs'}}, $job);
}

    
sub get_jobs{
    my ($self) = @_;

    $self->throw("BatchSubmmission object does not seem to contain any jobs.") unless @{$self->{'_jobs'}};

    return @{$self->{'_jobs'}};
}

sub batched_jobs{
    my ($self) = @_;
    return scalar(@{$self->{'_jobs'}});
}

sub empty_batch{
    my ($self) = @_;
    @{$self->{'_jobs'}} = ();
}


sub dbobj{
    my ($self,$arg) = @_;
    
    if (defined $arg){
        $self->{'_dbobj'} = $arg; 
    }

    return $self->{'_dbobj'};
}

sub stdout_file{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_stdout'} = $arg;
   }

   return $self->{'_stdout'};
}



sub stderr_file{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_stderr'} = $arg;
   }

   return $self->{'_stderr'};
}

sub parameters{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_parameters'} = $arg;
   }

   return $self->{'_parameters'};
}
sub pre_exec{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_pre_exec'} = $arg;
   }

   return $self->{'_pre_exec'};
}
sub command{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_command'} = $arg;
   }

   return $self->{'_command'};
}
sub queue{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_queue'} = $arg;
   }

   return $self->{'_queue'};
}
sub jobname{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_jobname'} = $arg;
   }

   return $self->{'_jobname'};
}
sub nodes{
   my ($self, $arg) = @_;

   if(defined($arg)){
     $self->{'_nodes'} = $arg;
   }

   return $self->{'_nodes'};
}

#############
#run methods#
#############

sub construct_command_line{
  my($self) = @_;

  $self->throw("Sorry, you cannot call this method from a generic BatchSumission Object");

}


sub open_command_line{
  my ($self)= @_;
  
  $self->throw("Sorry, you cannot call this method from a generic BatchSumission Object");

}

#implemeted submit_batch should implement the action parameter to pass to runner.pl which
#specifies the action to that the job undergoes according to the rule table
sub submit_batch{

  my ($self,$action)= @_;
  
  $self->throw("Sorry, you cannot call this method from a generic BatchSumission Object");

}
