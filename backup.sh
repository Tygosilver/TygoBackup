#!/bin/bash

# Скрипт должен читать из текстового файла список папок
# Которые нужно забэкапить

set -euo pipefail # Действия при ошибках -e: код немедленно остановится при любой ошибке (код != 0); -u: при необъявленной переменной остановит скрипт; -o: ошибка в любой части пайпа
date_stamp=$(date +'%Y-%m-%d')
time_stamp=$(date +'%H:%M:%S')

mkdir -p logs # -p: если папка имеется, то он не будет выдавать ошибку
mkdir -p backups
touch logs/logs_$(date +'%Y-%m-%d').txt


max_backups_for_restoration=3 #Переменная для контроля за количеством бэкапов в папке

err_report(){
    echo "[ ${time_stamp} ] [ ERROR ]  Ошибка в строке $1 команды: $2" >> logs/logs_$(date +'%Y-%m-%d').txt #Передача ошибки в скрипте идет через эту функцию
}

log(){
    if [ $# -gt 0 ]; then #если количество аргументов больше 0, то передаем их в лог, иначе передаем весь stdin
        echo "[ ${time_stamp} ] $*" >> logs/logs_$(date +'%Y-%m-%d').txt
    else
        while IFS= read -r line; do # IFS - Internal Field Separator (разделяет строки на отдельные фразы)
            echo "[ ${time_stamp} ] ${line}" >> logs/logs_$(date +'%Y-%m-%d').txt
        done
    fi
}

delete_backup(){ 
    
    # Автоудаление бэкапов 
    # Можно улучшить, так как он удаляет только один файл, соответственно если количество бэкапов больше чем на 1,  
    # то их всегда будет больше на 1 
    
    file_to_delete=""
    while IFS= read -ra files; do
        file_to_delete="${files[0]}"
    done <<< "$(ls -1 backups/$1 | sort -r)"

    log "Начинаю удаление файла: backups/$1/${file_to_delete}"
    rm -v backups/$1/${file_to_delete} 2>&1 | log

}

make_backup(){

line=""
while IFS='/' read -ra words; do
    for word in "${words[@]}"; do
        if [ "${word}" == "${words[-1]}" ]; then
            line+="/${word}"

            log "Выполняю архивацию ${line}!"

            # Автоматическое создание директории для папки которую хотим сохранить, если для нее до этого не существовало директории.

            if [ ! -d "backups/${word}" ]; then
                mkdir backups/${word}
                log "Директория создана"
            else
                log "Директория уже существует"
            fi

            tar -cvzf backups/${word}/${word}_${date_stamp}_${time_stamp}.tar.gz ${line} 2>&1 | log
            line=""

        else
            line+="/${word}"
        fi
    done
done < files.txt

}

make_backup

while IFS='\n' read -r folder; do
    if [ $(ls -1 backups/${folder} | wc -l) -gt ${max_backups_for_restoration} ]; then
        delete_backup ${folder}
    fi
done <<< "$(ls -1 backups)" 

trap 'err_report $LINENO "$BASH_COMMAND"' ERR