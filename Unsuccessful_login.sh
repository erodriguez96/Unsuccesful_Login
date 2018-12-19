#!/bin/bash

[[ $# -ne 1 ]] && echo "sobran o faltan argumentos, solo admito 1" && exit

#crea el fichero login_unsuccessful si no existe.
if [[ ! -f /var/log/login_unsuccessful ]]; then touch /var/log/login_unsuccessful; fi

#crea el primer fichero temporal a usar
if [[ ! -f ~/Escritorio/temporal.txt ]]; then touch ~/Escritorio/temporal.txt; fi
if [[ ! -f ~/Escritorio/temporal2.txt ]]; then touch ~/Escritorio/temporal2.txt; fi

fechaScript=$(date -r /var/log/login_unsuccessful "+%Y%m%d%H%M%S")
threshold=$1
cabecera=$(date "+%d/%m/%Y %H:%M:%S")

printf "usuarios con mas de $threshold accesos fallidos hasta: $cabecera\n" > /var/log/login_unsuccessful

function escribe(){
	#si hay entradas nuevas las apuntamos
	fechaUser=$(date -d"$1 $2 $3" "+%Y%m%d%H%M%S")
	if [[ $fechaUser -lt $fechaScript ]]
	then
		echo -n $4" ">> ~/Escritorio/temporal.txt
		echo $fechaUser >> ~/Escritorio/temporal.txt
	fi
}

#metemos al fichero temporal los usuarios con accesos fallidos para login y para ssh
grep "password check failed for " /var/log/secure | sed -e 's/[()]//g' | cut -d" " -f1,2,3,11 |  while read -r date1 date2 date3 name other
do
	escribe $date1 $date2 $date3 $name
done

grep "Failed password for " /var/log/secure | cut -d" " -f1,2,3,9 | while read -r date1 date2 date3 name other
do
	escribe $date1 $date2 $date3 $name
done

#ordenamos el fichero alfabeticamente para poder usar el uniq mas adelante
sort -d ~/Escritorio/temporal.txt > ~/Escritorio/temporal2.txt

printf "%-20s%-26s%-19s\n" "Nombre usuario" "Caducidad de contraseña" "Caducidad de cuenta" > ~/Escritorio/temporal.txt

#miraremos del fichero que ya tenemos ordenado y sacamos las lineas que se repiten mas de "threshold" veces en el archivo ordenado, ademas añadiremos la funcionalidad opcional con marcas de 'No' o 'Si' en funcion de si tienen o no caducidad de cuenta y contraseña.
cut -d" " -f1,2 ~/Escritorio/temporal2.txt | while read -r name date1 other
do
	#NO tiene caducidad de contraseña
	marca1="No"

	#NO tiene caducidad de cuenta
	marca2="No"
	
	if [[ $(grep -c ^"$name:" /etc/passwd) -ne 0 ]]
	then
		#The number of days after which password must be changed
		if [[ $(grep "$name" /etc/shadow | cut -d: -f5) -ne 99999 ]]; then marca1="Sí"; fi
		#The date of expiration of the account, an empty field means that the account will never expire.
		if [[ $(grep "$name" /etc/shadow | cut -d: -f8) -ne "" ]]; then marca2="Sí"; fi
	fi
	
	if [[ $(grep $name ~/Escritorio/temporal2.txt | wc -l) -ge $threshold ]]
	then 
		printf "%-20s%-25s%-19s\n" "$name" "$marca1" "$marca2" >> ~/Escritorio/temporal.txt
	fi
	
done

#volcamos las lineas que se repiten mas de "threshold" veces en el fichero login_unsuccessful y eliminamos los ficheros temporales creados
uniq ~/Escritorio/temporal.txt >> /var/log/login_unsuccessful

rm -f ~/Escritorio/{temporal.txt,temporal2.txt}
