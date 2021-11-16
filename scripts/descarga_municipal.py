#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on December 2020

@author: Rodrigo Zepeda
"""


import pandas as pd 
import os
from sys import argv
from selenium import webdriver
from selenium.webdriver.support.select import Select
import time
from datetime import date, timedelta
from datetime import datetime

direccion_chromedriver = '/usr/local/bin/chromedriver'

#Case for windows
if os.name == 'nt':
    slash = "\\"
else:
    slash = "/"

#Checar
if len(argv) == 3:
    descargar_desde, descargar_hasta, = argv[1:]
elif len(argv) == 2:
    descargar_desde = argv[1:]
    descargar_hasta = (date.today() - timedelta(days=1)).strftime('%Y-%m-%d')
else:
    files_downloaded = os.listdir("raw" + slash + "unidad_medica")
    files_downloaded = [e.replace("UCI_", "").replace(".csv", "") for e in files_downloaded if e.startswith('UCI')]
    dates_downloaded = [datetime.strptime(e,'%Y-%m-%d') for e in files_downloaded]
    descargar_desde  = (max(dates_downloaded) + timedelta(days=1)).strftime('%Y-%m-%d')
    descargar_hasta  = (date.today() - timedelta(days=1)).strftime('%Y-%m-%d')

    estatal = False    #Poner como true si quieres datos estatales; como false si quieres clues pero aún no funciona el false 

    

if datetime.strptime(descargar_desde,'%Y-%m-%d') <= datetime.strptime(descargar_hasta,'%Y-%m-%d'):
    #Imprimir lo que se está haciendo
    print("Descargando datos municipales desde " + descargar_desde +  " hasta " + descargar_hasta)
    
    
    folder_of_download = os.getcwd() + slash + "raw" + slash + "unidad_medica" 
    sleep_time    = 60 #Tiempo que tarda la página de la UNAM de cambiar ventana
    download_time = 30  #Tiempo que tarda en descargarse el archivo en tu red
    
    
    option = webdriver.ChromeOptions()
    option.add_argument('--disable-gpu')  # Last I checked this was necessary.
    option.add_argument("-incognito")
    #option.add_argument("--headless")
    
    option.add_experimental_option("prefs", {
            "download.default_directory": folder_of_download,
            "download.prompt_for_download": False,
            "download.directory_upgrade": True,
            "safebrowsing_for_trusted_sources_enabled": False,
            "safebrowsing.enabled": False
    })
    
    browser = webdriver.Chrome(executable_path=direccion_chromedriver, options=option)
    browser.set_window_size(1000,1000)
    browser.get("https://www.gits.igg.unam.mx/red-irag-dashboard/reviewHome#")
    
    #Dar click en entrar
    time.sleep(sleep_time)
    browser.find_element_by_id('enter-button').click()
    
    #Fechas a descargar
    fechas_descargar = pd.date_range(start = descargar_desde, end = descargar_hasta, freq='D') 
    fechas_descargar = fechas_descargar.strftime('%Y-%m-%d')
    
    #Impresión de tiempo estimado
    print("Tiempo estimado: " + str(len(fechas_descargar)*(sleep_time*4 + 4*download_time)/360) + " horas")

    # Elementos de resumen, ocupación general, camas y uci
    resumen    = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[1]/a")
    hospital   = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[5]/a")
    ventilador = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[6]/a")
    uci        = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[7]/a")
    
    #Avance para cuantificar
    avance = 0
    
    for fecha_analisis in fechas_descargar:
            
        print("Descargando " + str(100*avance/len(fechas_descargar)) + "%")
        avance = avance + 1
        
        #Asegurarnos que estamos en la sección resumen
        resumen.click()
        time.sleep(sleep_time)
            
        select = Select(browser.find_element_by_id("dateSelected"))
        select.select_by_visible_text(fecha_analisis)
        time.sleep(download_time)
    
    
        # --------------------------------
        # HOSPITALIZACIONES
        # --------------------------------
        
        hospital.click()
        time.sleep(sleep_time)
        
        #Cambiar el formato a estatal
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/nav/ul/li[4]/a").click()
        time.sleep(sleep_time) 
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]/span").click()
            
        
        newname = "Hospitalizaciones_" + fecha_analisis + ".csv"   #Segun yo no importa que el nombre se quede igual por las carpetas
        time.sleep(download_time)
        os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
        
        # --------------------------------
        # VENTILADORES
        # --------------------------------
        
        ventilador.click()
        time.sleep(sleep_time)
    
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/nav/ul/li[4]/a").click()
        time.sleep(sleep_time)
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]/span").click()

        newname = "Ventiladores_" + fecha_analisis + ".csv"
        time.sleep(download_time)
        os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
        
        # --------------------------------
        # UCI
        # --------------------------------
        
        uci.click()
        time.sleep(sleep_time)
        
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/nav/ul/li[4]/a").click()
        time.sleep(sleep_time)
        browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]/span").click()   
        
        newname = "UCI_" + fecha_analisis + ".csv"
        time.sleep(download_time)
        os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
            
    browser.close()
else:
    print("Ya está descargado lo más que se puede")
