#!/bin/sh -

# *.prv is the password protected *.key

for i in *.prv
do 
	openssl rsa -in $i -passin file:./password.txt -out ${i%.prv}.key
	chmod 600 ${i%.prv}.key
done
