# MySQL dump 8.13
#
# Host: localhost    Database: test_run
#--------------------------------------------------------
# Server version	3.23.36

#
# Dumping data for table 'analysis'
#

INSERT INTO analysis VALUES (1,'2002-07-26 16:22:45','blast','Bio::Pipeline::Runnable::TestRunnable',NULL,NULL,NULL,NULL,'testrun',NULL,NULL,'','test',NULL,NULL,0);
INSERT INTO analysis VALUES (2,'2002-07-26 16:22:46','blast','Bio::Pipeline::Runnable::TestRunnable',NULL,NULL,NULL,NULL,'testrun',NULL,NULL,'','test',NULL,NULL,0);

#
# Dumping data for table 'analysis_output_handler'
#

INSERT INTO analysis_iohandler VALUES (1,2,NULL,NULL);
INSERT INTO analysis_iohandler VALUES (2,2,NULL,NULL);

#INSERT INTO converter VALUES (1,'Bio::Pipeline::TestConverter','convertBioToEns');

#
# Dumping data for table 'argument'
#

INSERT INTO argument VALUES (1,1,'-file','t/data/testin.fa',1,'SCALAR');
INSERT INTO argument VALUES (2,1,'-format','Fasta',2,'SCALAR');
INSERT INTO argument VALUES (3,3,'-file','>t/data/testout.fa',1,'SCALAR');
INSERT INTO argument VALUES (4,3,'-format','Fasta',2,'SCALAR');
INSERT INTO argument VALUES (5,4,NULL,'!OUTPUT!',1,'ARRAY');

#
# Dumping data for table 'completed_jobs'
#


#
# Dumping data for table 'datahandler'
#

INSERT INTO datahandler VALUES (1,1,'new',1);
INSERT INTO datahandler VALUES (2,1,'next_seq',2);
INSERT INTO datahandler VALUES (3,2,'new',1);
INSERT INTO datahandler VALUES (4,2,'write_seq',1);

#
# Dumping data for table 'dbadaptor'
#


#
# Dumping data for table 'input'
#

INSERT INTO input VALUES (1,'test1','',1,1);
INSERT INTO input VALUES (2,'test2','',2,1);

#
# Dumping data for table 'iohandler'
#

INSERT INTO iohandler VALUES (1,1,'INPUT','STREAM');
INSERT INTO iohandler VALUES (2,1,'OUTPUT','STREAM');

#
# Dumping data for table 'job'
#

INSERT INTO job VALUES (1,'NEW',1,0,'','','','NEW','','',0);
INSERT INTO job VALUES (2,'NEW',1,0,'','','','NEW','','',0);

#
# Dumping data for table 'new_input'
#


#
# Dumping data for table 'new_input_ioh'
#


#
# Dumping data for table 'node'
#

INSERT INTO node VALUES (1,'59',1);

#
# Dumping data for table 'node_group'
#

INSERT INTO node_group VALUES (1,'gr1','desc1');

#
# Dumping data for table 'output'
#


#
# Dumping data for table 'rule'
#

INSERT INTO rule VALUES (1,1,2,'WAITFORALL_AND_UPDATE');

#
# Dumping data for table 'streamadaptor'
#

INSERT INTO streamadaptor VALUES (1,'Bio::SeqIO','','');

