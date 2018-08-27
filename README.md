This project requires that Mojolicious be installed 
This project also requires that Path::Class be installed 
please install Mojolicious using the following command 
curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojolicious'
install Path::Class 
cpamn Path::Class 

to run this, check out the project and after the installation 
You should see a cache dir and wordfinder.pl 


run morbo wordfinder.pl 
if all is well you should see 
Server available at http://127.0.0.1:3000 

on another tab in terminal say 
curl localhost:3000/ping 
you should now get a 200 OK

to use the word finder say 
curl localhost:3000/wordfinder/<characrers>
 eg  curl localhost:3000/wordfinder/gab  
