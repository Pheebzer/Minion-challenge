#!bin/bash

counter=1
num=1

while [ $counter -le 35 ]
do
         vagrant ssh node$num -c "hostname; cat /tmp/hello.txt"
	((counter++))
	((num++))
done

echo "Script done."

