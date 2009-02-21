# BioPerl runnable for Bio::Pipeline::BatchSubmission::LSF
# 
# Based on the EnsEMBL module 
# Bio::EnsEMBL::Pipeline::BatchSubmission::LSF
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

Bio::Pipeline::BatchSubmission::LSF

=head1 SYNOPSIS

  my $batchsub = Bio::Pipeline::BatchSubmission::LSF->new(
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

The wrapper to the LSF job management system.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-pipeline@bioperl.org          - General discussion
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

=head1 AUTHOR

Email fugui@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

# Let the code begin...



package Bio::Pipeline::BatchSubmission::LSF;

use Bio::Pipeline::BatchSubmission;
use Bio::Root::Root;
use vars qw(@ISA); 
use strict;

use Bio::Pipeline::PipeConf qw (RUNNER
                                NFSTMP_DIR
                                );


@ISA = qw(Bio::Pipeline::BatchSubmission) ;

=head2 submit_batch

  Title    : submit_batch
  Function : do the actual job submission to LSF
  Example  : $bs->submit_batch
  Returns  : true if successful
  Args     :

=cut

sub submit_batch{
    my ($self) = @_;

    my @job_ids;

    my $jobadaptor = $self->dbobj->get_JobAdaptor;


    #making the stderr and stdout files.
    my $num = int(rand(10));
    my $file = $NFSTMP_DIR."/$num/";
    if (! -e $file){
        system ("mkdir $file");
    }

    my @jobs = $self->get_jobs;
    
    foreach my $job(@jobs){
        push (@job_ids,$job->dbID);
        $file .= $job->dbID."_";        
    }

    $file .= $jobs[0]->analysis->logic_name.".".time().".".int(rand(1000));
    $self->stdout_file($jobs[0]->stdout_file);
    $self->stderr_file($jobs[0]->stderr_file);

    my $bsub = $self->construct_command_line;

    my $runner = $self->runner_path || $RUNNER || undef;

    unless ($runner && -x $runner) {
        $runner = __FILE__;
        $runner =~ s:/([^/]*/[^/]*/[^/]*/[^/]*)$:/scripts/runner.pl:;
        $self->throw("Can't locate runner.pl - needs to be set in PipeConf.pm") unless -x $runner;
    }

    #pass runner the db info
    $runner = $self->construct_runner_param($runner);

    $bsub .= "$runner ".join(" ",@job_ids);

    print STDERR "opening bsub command line:\n $bsub\n";
    
    open (SUB,$bsub." 2>&1|");

    my $lsf;
    while(<SUB>){
        if (/Job <(\d+)>.*queue <(\w+)>/) {
            $lsf = $1;
        }
    }

    if (! defined $lsf){
        print STDERR "couldn't submit jobs ".join(" ",@job_ids)." to LSF.\n";
        foreach my $job (@jobs){
            $job->set_status('FAILED');
        }
    }else{
        foreach my $job (@jobs){
            $job->set_status('SUBMITTED');
            $job->queue_id($lsf);
            $job->adaptor->update($job);
        }
    }
    close (SUB);

    $self->empty_batch;
    
    return 1;

}

=head2 construct_command_line

  Title    : construct_command_line
  Function : constructs the LSF command line
  Example  : $command = $bs->construct_command_line;
  Returns  : a string
  Args     : a string

=cut

sub construct_command_line{

    my ($self) = @_;

    my $bsub_line;
#    $bsub_line = "bsub ";
    $bsub_line = "bsub -o ".$self->stdout_file;

    $bsub_line .= " -e ".$self->stderr_file;

    if($self->nodes){
        my $nodes = $self->nodes;
    # $nodes needs to be a space-delimited list
        $nodes =~ s/,/ /;
        $nodes =~ s/ +/ /;
    # undef $nodes unless $nodes =~ m{(\w+\ )*\w};
        $bsub_line .= " -m '".$nodes."' ";
    } 

    $bsub_line .= " -q ".$self->queue    if defined $self->queue;
    $bsub_line .= " -J ".$self->jobname  if defined $self->jobname;
    $bsub_line .= " ".$self->parameters." "  if defined $self->parameters;
    $bsub_line .= " -E \"".$self->pre_exec."\"" if defined $self->pre_exec;
    $bsub_line .= " ";
    
    return $bsub_line;

}

=head2 get_host_name

  Title    : get_host_name
  Function : get the hostname from the lsf output taking in
             as input the log file name.
  Example  : $name= $bs->get_host_name($job->stderr_out);
  Returns  : a string
  Args     : a string

=cut

sub get_host_name {
  my ($self,$queue_id) = @_;
  open(LOG,"bjobs -l ".$queue_id."|");
  while(<LOG>){
    chomp;
    print STDERR "Log: $_.\n";
    if(/Started on\s+<(\S+)>/){
       print STDERR "GOTCHA$1\n";
      return $1;
    }
  }
  return;
}
  
    
1;
