#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on December 2020

@author: Rodrigo Zepeda
"""


import pandas as pd 
import os
from selenium import webdriver
from selenium.webdriver.support.select import Select
import time
    
 
folder_of_download = "/Users/rod/Dropbox/HospitalizacionesCOVIDMX/raw"
direccion_chromedriver = '/Users/rod/Dropbox/HospitalizacionesCOVIDMX/chromedriver'
descargar_desde = "2020-12-28"
descargar_hasta = "2021-01-18"
sleep_time    = 10 #Tiempo que tarda la página de la UNAM de cambiar ventana
download_time = 2  #Tiempo que tarda en descargarse el archivo en tu red

"""
#Funcion para obtener las tarjetas de resumen
def card_convert(browser, xpath):
    numeric_intrnal = browser.find_element_by_xpath(xpath)
    numeric_intrnal = numeric_intrnal.get_attribute("innerHTML")
    numeric_intrnal = ''.join(e for e in numeric_intrnal if e.isalnum())
    numeric_intrnal = int(numeric_intrnal)
    return numeric_intrnal
"""

option = webdriver.ChromeOptions()
option.add_argument("-incognito")

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
fechas_descargar = fechas_descargar[::-1]

#Impresión de tiempo estimado
print("Tiempo estimado: " + str(len(fechas_descargar)*(sleep_time*4 + 4*download_time)/360) + " horas")

#Elementos de resumen, ocupación general, camas y uci
resumen    = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[1]/a")
hospital   = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[4]/a")
ventilador = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[5]/a")
uci        = browser.find_element_by_xpath("/html/body/section/section[2]/div[1]/nav/ul/li[6]/a")

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



    '''
    # --------------------------------
    # RESUMEN
    # --------------------------------
    
    
    #Unidades médicas que no reportaron dos días consecutivos
    unidades_dos = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[1]/div[1]/span[2]")
    
    #Unidades médicas que no reportaron este día
    unidades_este = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[1]/div[2]/span[2]")
    
    #Hospitalizado IRAG no UCI
    hosp_irag = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[1]/div[3]/span[2]")
    
    #Unidades con 70% hospitalización
    unidades_70hosp = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[1]/span[2]")
    
    #Unidades con 70% ventiladores
    unidades_70vent = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[2]/span[2]")
    
    #Unidades con 70% UCI
    unidades_70UCI = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[3]/span[2]")
    
    #Unidades entre 50 y 70 de hospitalización
    unidades_50hosp = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[4]/span[2]")
    
    #Unidades entre 50 y 70 de ventilador
    unidades_50vent = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[5]/span[2]")
    
    #Unidades entre 50 y 70 UCI
    unidades_50UCI  = card_convert(browser,"/html/body/section/section[2]/div[2]/section/article[1]/div[2]/div[2]/div/div[4]/div[6]/span[2]")
    '''     
    # --------------------------------
    # HOSPITALIZACIONES
    # --------------------------------
    
    hospital.click()
    time.sleep(sleep_time)
     
    browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]").click()
    newname = "Hospitalizaciones_" + fecha_analisis + ".csv"
    time.sleep(download_time)
    os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
    
    # --------------------------------
    # VENTILADORES
    # --------------------------------
    
    ventilador.click()
    time.sleep(sleep_time)

    browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]").click()
    newname = "Ventiladores_" + fecha_analisis + ".csv"
    time.sleep(download_time)
    os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
    
    # --------------------------------
    # UCI
    # --------------------------------
    
    uci.click()
    time.sleep(sleep_time)

    browser.find_element_by_xpath("/html/body/section/section[2]/div[2]/section/article[2]/article/div[1]/div/div[5]/div/div[1]/button[1]").click()
    newname = "UCI_" + fecha_analisis + ".csv"
    time.sleep(download_time)
    os.rename(os.path.join(folder_of_download, "Sistema de Información de la Red IRAG.csv"), os.path.join(folder_of_download, newname))
        
browser.close()
