#!/bin/bash

# -f   : fragmentation 
# -ibn : ignore blank node if t(rue) argument, false else 
# -owl : ontology 
# -nt  : triple files 
# -out : output file 
# -q   : query

HOME=$(pwd)

if [ "$1" = "start" ]; then 

# Ontop Materialize
 java -Xms1024M -Xmx2048M -cp lib/ontop-materializer-1.16.jar ontop.Main -owl mapping/AnaEE.owl -obda mapping/lac.obda -out out/ontopMaterializedTriples.nt -q " SELECT DISTINCT ?s ?p ?o {?s ?p ?o .} "

# Corese Inferer 
 java -Xms1024M -Xmx2048M -cp lib/coreseInfer.jar corese.Main -owl mapping/AnaEE.owl -nt out/ontopMaterializedTriples.nt -q " SELECT DISTINCT ?s ?p ?o WHERE {?s ?p ?o . }" -out out/store/coreseInferedTriples.nt -f 50000 -ibn t -q " PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> PREFIX : <http://www.anaee/fr/soere/ola#> PREFIX oboe-core: <http://ecoinformatics.org/oboe/oboe.1.0/oboe-core.owl#> select ?uriVariableSynthesis ?measu ?value  { ?uriVariableSynthesis a oboe-core:Observation ; oboe-core:ofEntity :VariableSynthesis ; oboe-core:hasMeasurement ?measu . ?measu oboe-core:hasValue ?value . Filter ( regex( ?value, 'ph', 'i'))}" -out out/portail/coreseInferedTriples.nt -f 0 -ibn t

#COMMAND <<INPUT_DELIMETER

# Index Store 
 SOLRDF_HOME_STORE=$HOME"/index/store"
 SOLRDF_COLLECTION_STORE=$HOME"/index/store/store"
 SOLRDF_COLLECTION_STORE_CONFDIR=$HOME"/index/store/store/conf"

# Index Portail
 SOLRDF_HOME_PORTAIL=$HOME"/index/portail"
 SOLRDF_COLLECTION_PORTAIL=$HOME"/index/portail/portail"
 SOLRDF_INDEX_PORTAIL_CONFDIR=$HOME"/index/portail/portail/conf"

 cd $HOME"/lib/zookeeper-3.4.6/bin"

 ./zkServer.sh start

 cd $HOME"/lib/solr-5.3.1/server/scripts/cloud-scripts"

 ./zkcli.sh -cmd upconfig -zkhost 127.0.0.1:2181 -confname store   -solrhome $SOLRDF_COLLECTION_STORE   -confdir $SOLRDF_COLLECTION_STORE_CONFDIR

 ./zkcli.sh -cmd upconfig -zkhost 127.0.0.1:2181 -confname portail -solrhome $SOLRDF_COLLECTION_PORTAIL -confdir $SOLRDF_INDEX_PORTAIL_CONFDIR

 cd $HOME"/lib/solr-5.3.1/bin"

 ./solr -cloud -p 6981 -s $SOLRDF_HOME_STORE   -a "-Dsolr.data.dir=$HOME/data/cluster_01/node_01 -Dname=store   -Dshard=shard1 -DnumShards=2 " -zkhost localhost:2181 -m 2048m

 ./solr -cloud -p 6982 -s $SOLRDF_HOME_STORE   -a "-Dsolr.data.dir=$HOME/data/cluster_01/node_02 -Dname=store   -Dshard=shard2 -DnumShards=2 " -zkhost localhost:2181 -m 2048m 

 #./solr -cloud -p 6983 -s $SOLRDF_HOME_STORE   -a "-Dsolr.data.dir=$HOME/data/cluster_01/node_03 -Dname=store   -Dshard=shard3 -DnumShards=3 " -zkhost localhost:2181 -m 1024m

 ./solr -cloud -p 6985 -s $SOLRDF_HOME_PORTAIL -a "-Dsolr.data.dir=$HOME/data/cluster_02/node_01 -Dname=portail -Dshard=shard1 -DnumShards=1 " -zkhost localhost:2181 -m 1024m



 cd "$HOME/out/store"

 for i in `ls -a *.*`
 do
   if [ "$i" != "bulk" ]; then
    
     echo "--------------------------------------"
     echo "load data file : $i"
     curl -v http://localhost:6981/solr/store/update/bulk -H "Content-Type: application/n-triples" --data-binary @"$i" -O
     echo "-------------------------------------"
   
  fi
 done

 cd "$HOME/out/portail"

 for j in `ls -a *.*`
 do
   if [ "$i" != "bulk" ]; then
   
      echo "--------------------------------------"
      echo "load data file : $j"
      curl -v http://localhost:6985/solr/portail/update/bulk -H "Content-Type: application/n-triples" --data-binary @"$j" -O
      echo "-------------------------------------"    
   fi
 done


#curl "http://localhost:6981/solr/store/sparql" --data-urlencode "q=PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> PREFIX : <http://www.anaee/fr/soere/ola#> PREFIX oboe-core: <http://ecoinformatics.org/oboe/oboe.1.0/oboe-core.owl#> select ?uriVariableSynthesis ?measu ?value  { ?uriVariableSynthesis a oboe-core:Observation ; oboe-core:ofEntity :VariableSynthesis ; oboe-core:hasMeasurement ?measu . ?measu oboe-core:hasValue ?value . Filter ( regex( ?value, 'ph', 'i'))}" -H "Accept: text/csv"

#curl "http://localhost:6981/solr/store/sparql" --data-urlencode "q=PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> PREFIX : <http://www.anaee/fr/soere/ola#> PREFIX oboe-core: <http://ecoinformatics.org/oboe/oboe.1.0/oboe-core.owl#> select ?uriVariableSynthesis ?measu ?value ?concentration { ?uriVariableSynthesis a oboe-core:Observation ; oboe-core:ofEntity :VariableSynthesis ;  oboe-core:hasMeasurement ?measu ; oboe-core:hasContext ?soluteObservation . ?measu oboe-core:hasValue ?value . ?soluteObservation a oboe-core:Observation ; oboe-core:hasMeasurement ?measureSolute .?measureSolute a oboe-core:Measurement ; oboe-core:hasValue ?concentration . }" -H "Accept: text/csv"



#INPUT_DELIMETER

else

if [ "$1" = "stop" ]; then 

cd $HOME"/lib/zookeeper-3.4.6/bin"

./zkServer.sh stop

cd $HOME"/lib/solr-5.3.1/bin"

./solr stop -all

else 

echo "parameter : start - stop "

fi 
fi 


# -H "Accept: text/tab-separated-values"
# -H "Accept: application/sparql-results+json"

