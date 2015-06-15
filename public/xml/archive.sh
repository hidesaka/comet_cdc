dirs=`find . -type d -name "201*"`
for dir in $dirs
do
   echo $dir
   cd $dir
   if [ ! -e "COMETCDC.xml" ]
   then
      echo "No COMETCDC.xml in $dir"
      cd -
      continue
   fi
   if [ ! -e "COMETCDC.tgz" ]
   then
      tar czvf COMETCDC.tgz COMETCDC.xml && rm COMETCDC.xml
   else
      echo "Already .tgz in $dir"
   fi

   cd -
done
