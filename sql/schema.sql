#job - holds the job information necessary for job tracking.
#analysis_id is the foreign key to analysis table
#added process_id to job - all the jobs associated with a single pipeline run are identified by this process_id
CREATE TABLE job (
  job_id             int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  process_id         varchar(100) DEFAULT 'NEW' NOT NULL,
  analysis_id        int(10) unsigned DEFAULT '0',
  queue_id           int(10) unsigned DEFAULT '0',
  stdout_file        varchar(100) DEFAULT '',
  stderr_file        varchar(100) DEFAULT '',
  object_file        varchar(100) DEFAULT '',
  status             varchar(20) DEFAULT 'NEW' NOT NULL,
  stage              varchar(20) DEFAULT '',
  time               datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  retry_count        int default 0,

  PRIMARY KEY (job_id),
  KEY (process_id),
  KEY (analysis_id)
);

#dynamic_argument - holds the run-time generated arguments 
#datahandler_id is the foreign key to the datahandler table
CREATE TABLE dynamic_argument(
  input_id             int(10) unsigned DEFAULT '0' NOT NULL ,
  datahandler_id     int(10) unsigned NOT NULL,
  tag             varchar(40) DEFAULT '',
  value           varchar(40) DEFAULT '',
  rank            int(10) DEFAULT 1 NOT NULL,
  type            enum('SCALAR','ARRAY') DEFAULT 'SCALAR' NOT NULL,

  PRIMARY KEY (input_id,datahandler_id,rank),
  KEY(datahandler_id)
);

#input_create_argument - holds the arguments necessary for input creates

CREATE TABLE input_create_argument (
  input_create_argument_id    int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  input_create_id    int(10) unsigned DEFAULT '0' NOT NULL ,
  tag             varchar(40) DEFAULT '',
  value           varchar(255) DEFAULT '',

  PRIMARY KEY (input_create_argument_id)
);

#input_creates - input creates are specialized runnables used for generating inputs and job automatiaclly 

CREATE TABLE input_create (
  input_create_id  int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  data_monger_id int(10) unsigned DEFAULT '0' NOT NULL ,
  module varchar(40) DEFAULT '' NOT NULL,
  rank            int(10) DEFAULT 1 NOT NULL,
  
  PRIMARY KEY(input_create_id)
);

#iohandler - iohandlers contain the methods calls necessary for fetching inputs and storing outputs   
#adaptor_id is the foreign key to the stream_adaptor or dbadpator tables

CREATE TABLE iohandler (
   iohandler_id         int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
   adaptor_id           int(10) DEFAULT '0' NOT NULL,
   type                 enum ('INPUT','OUTPUT') NOT NULL,
   adaptor_type         enum('DB','STREAM') DEFAULT 'DB' NOT NULL,

   PRIMARY KEY (iohandler_id),
   KEY adaptor (adaptor_id)
);

# datahandler - holds the method calls used for iohandlers
# iohandler_id is the foreign key to the iohandler table

CREATE TABLE datahandler(
    datahandler_id     int(10) unsigned NOT NULL auto_increment,
    iohandler_id        int(10) DEFAULT '0' NOT NULL,
    method              varchar(60) DEFAULT '' NOT NULL,
    rank                int(10) DEFAULT 1 NOT NULL,

    PRIMARY KEY (datahandler_id),
    KEY iohandler (iohandler_id)
);

#argument - holds the arguments for datahandler methods
#datahandler_id is the foreign key to the datahandler table

CREATE TABLE argument (
  argument_id     int(10) unsigned NOT NULL auto_increment,
  datahandler_id  int(10) unsigned NOT NULL ,
  tag             varchar(40) DEFAULT '',
  value           varchar(255) DEFAULT '',
  rank            int(10) DEFAULT 1 NOT NULL,
  type            enum('SCALAR','ARRAY') DEFAULT 'SCALAR' NOT NULL,

  PRIMARY KEY (argument_id)
);

#dbadaptor - holds the database connection information

CREATE TABLE dbadaptor (
   dbadaptor_id   int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
   dbname         varchar(40) DEFAULT '' NOT NULL,
   driver         varchar (40) DEFAULT '' NOT NULL,
   host           varchar (40) DEFAULT '',
   port           int(10) unsigned  DEFAULT '',
   user           varchar (40) DEFAULT '',
   pass           varchar (40) DEFAULT '',
   module         varchar (100) DEFAULT '',
   
   PRIMARY KEY (dbadaptor_id)
);

#streamadaptor - holds the module name of stream adaptors
CREATE TABLE streamadaptor (
  streamadaptor_id  int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  module          varchar(40) DEFAULT '' NOT NULL,
  file_path        mediumtext DEFAULT '',
  file_suffix     varchar(40) DEFAULT '',

  PRIMARY KEY (streamadaptor_id)
);

#input - input table that holds input names which are keys used for fetching objects on which
#analysis is run
#iohandler_id is the foreign key to the iohandler table
#job_id is the foreign key to the job table

CREATE TABLE input (
   input_id         int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
   name             varchar(255) DEFAULT '' NOT NULL,
   tag              varchar(40) DEFAULT '',
   job_id           int(10) unsigned NOT NULL,
   iohandler_id     int(10) unsigned ,

   PRIMARY KEY (input_id),
   KEY iohandler (iohandler_id),
   KEY job (job_id)

);

#DEPRECATED??
CREATE TABLE output (
  job_id           int(10) unsigned DEFAULT '0' NOT NULL,
  output_name             varchar(40) DEFAULT '' NOT NULL,
  PRIMARY KEY (job_id, output_name)
);

# created new table to reflect the inputs generated (as outputs of an analysis)- currently an analysis can generate
# outputs as inputs only for the next analysis  
#DEPRECATRED??
CREATE TABLE new_input (
  input_id         int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  job_id           int(10) unsigned DEFAULT '0' NOT NULL,
  name             varchar(40) DEFAULT '' NOT NULL,
  PRIMARY KEY (input_id)
  #PRIMARY KEY (job_id,name,new_input_ioh_id);
  
);

# rule - rules defining the behavior of the pipeline. Rules are used when jobs are completed to decide what the next
# action to do is. 
# NOTHING 	- Do nothing next. No new jobs are created.
# UPDATE 	- convert the outputs of the previous analysis as inputs to the next analysis -creates one job per input
# WAITFORALL 	- the new job for the next analysis will be created only when all the jobs of the previous analysis are
# completed, the outputs of the previous jobs are not set as inputs to the next job
# WAITFORALL_AND_UPDATE - same as WAITFORALL but the outputs are set as inputs for the next job
# COPY_ID 	- copys the input id from the previous jobs to the next, mapping the iohandlers using the iohandler_map table
# COPY_INPUT    - copys the input id and the iohandler ids from the previous job to the next
# COPY_ID_FILE  - copys the input id from the previous job to the next and adding the tag infile 

CREATE TABLE rule (
  rule_id          int(10) unsigned DEFAULT'0' NOT NULL auto_increment,
  current          int(10) unsigned DEFAULT '',
  next             int(10) unsigned NOT NULL,
  action           enum('WAITFORALL','WAITFORALL_AND_UPDATE','UPDATE','NOTHING','COPY_INPUT','COPY_ID','CREATE_INPUT','COPY_ID_FILE'),
  
  PRIMARY KEY (rule_id)
);

#analysis - This contains the analysis configuration.
CREATE TABLE analysis (
  analysis_id      int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  created          datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  logic_name       varchar(40) not null,
  runnable         varchar(80),
  db               varchar(120),
  db_version       varchar(40),
  db_file          varchar(120),
  program          varchar(80),
  program_version  varchar(40),
  program_file     varchar(80),
  data_monger_id   int(10) unsigned DEFAULT '',
  runnable_parameters varchar(255),
  analysis_parameters       mediumtext,
  gff_source       varchar(40),
  gff_feature      varchar(40),
  node_group_id    int(10) unsigned DEFAULT '0' NOT NULL,

  PRIMARY KEY (analysis_id)
);

#analysis_iohandler - This is used to link analysis with iohandlers. Each analysis may have more than one iohandler
#and for each iohandler there may be more than one transformer.

CREATE TABLE analysis_iohandler(
  analysis_id               int(10) NOT NULL,
  iohandler_id              int(10) NOT NULL,
  transformer_id            int(10) ,
  transformer_rank          int(2) ,
  UNIQUE (analysis_id,iohandler_id,transformer_id)

);

#transformer - Transformers includes Filters and Converters currently. It is meant to also
#include any set of data processing and are part of the IOHandlers.
#These work at two points :
#	1) After inputs are fetch and before they are passed to the analysis
#	2) After outputs are generated and before they are stored in the database
 
CREATE TABLE transformer(
	transformer_id		int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  	module			varchar(255)	 NOT NULL,
  	PRIMARY KEY (transformer_id)
);

#transformer_method - holds method names of transformers. These are cascaded and called 
#in the order sepecified by the rank 
#transformer_id is the foreign key to the transformer table

CREATE TABLE transformer_method(
	transformer_method_id	INT(10) UNSIGNED DEFAULT '0' NOT NULL AUTO_INCREMENT,
	transformer_id 		INT(10) UNSIGNED NOT NULL,
	name			VARCHAR(40) NOT NULL,
	rank			INT(2) ,

	PRIMARY KEY(transformer_method_id),
	KEY(transformer_id)
);

# transformer_argument - holds the arguments for the transformer methods and are passed into the method
# in the order specified by the rank
# transformer_method_id is the foreign key to the transformer_method table

CREATE TABLE transformer_argument(
	transformer_argument_id 	int(10) unsigned DEFAULT '0' NOT NULL AUTO_INCREMENT,
	transformer_method_id 	INT(10) UNSIGNED NOT NULL,
	tag 			VARCHAR(40),
	value 			VARCHAR(40) NOT NULL,
	rank			INT(2) UNSIGNED ,

	PRIMARY KEY(transformer_argument_id)
);

#completed_jobs - holds the list of jobs that have been completed and removed from the job table.

CREATE TABLE completed_jobs (
  completed_job_id      int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  process_id            varchar(100) DEFAULT 'NEW' NOT NULL,
  analysis_id           int(10) unsigned DEFAULT '0',
  queue_id              int(10) unsigned DEFAULT '0',
  stdout_file           varchar(100) DEFAULT '' NOT NULL,
  stderr_file           varchar(100) DEFAULT '' NOT NULL,
  object_file           varchar(100) DEFAULT '' NOT NULL,
  time                  datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  retry_count           int default 0,

  PRIMARY KEY (completed_job_id),
  KEY analysis (analysis_id)
);

#node - not used currently. This is meant for future specification of the nodes that
#belong to a particular group

CREATE TABLE node (
  node_id               int(10) unsigned DEFAULT '0' NOT NULL auto_increment,
  node_name             varchar(40) DEFAULT '' NOT NULL,
  group_id              int(10) unsigned DEFAULT '0' NOT NULL,

  PRIMARY KEY (node_id,group_id)
);

#node_group - not used currently. This is meant to group nodes together for job submission management

CREATE TABLE node_group (
  node_group_id         int(10) unsigned NOT NULL auto_increment,
  name                  varchar(40) NOT NULL,
  description           varchar(255) NOT NULL,

  PRIMARY KEY (node_group_id),
  KEY (name)
);

#iohandler_map - this holds the mapping of iohandlers between analysis. This is to handle
#cases where the different inputs may be fetched using the same input id. For example
#fetch_seq and fetch_repeatmasked_seq

CREATE TABLE iohandler_map(
 prev_iohandler_id             int(10) DEFAULT '',
 analysis_id                   int(10) NOT NULL,
 map_iohandler_id              int(10) NOT NULL,

 PRIMARY KEY (analysis_id,map_iohandler_id)
);
