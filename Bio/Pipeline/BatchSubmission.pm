package Bio::Pipeline::BatchSubmission;

use vars qw(@ISA);
use strict;
use Bio::Root::Root;

use Bio::Pipeline::PipeConf qw( BATCH_MOD);


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

sub _empty_batch{
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
     $self->{'_paramemters'} = $arg;
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

sub run_batch{

    #clear @$self->{'_job_ids'};

}
