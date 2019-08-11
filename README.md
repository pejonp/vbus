# VBUS LAN Adapter Device

 (c) 2014 Arno Willig <akw@bytefeed.de>
 
 (c) 2015 Frank Wurdinger <frank@wurdinger.de>
 
 (c) 2015 Adrian Freihofer <adrian.freihofer gmail com>

# 19_VBUSIF.pm    VBUS LAN Adapter Device


# VBUS Client Device

 (c) 2014 Arno Willig <akw@bytefeed.de>  2014-03-03 19:33:15Z akw 

# 21_VBUSDEV.pm   VBUS Client Device 


http://danielwippermann.github.io/resol-vbus/index.html



The Perl modules can be loaded directly into your FHEM installation:

 update all https://raw.githubusercontent.com/pejonp/vbus/master/controls_vbus.txt



Hier die schon hinterlegten Geräte. 
======

|Code | Geräte|Bemerkung|
| ------------- | ----------- | ----------- |
|0050 |  DL_2 | Beipielkonfig DeltaSol_M (0x7311): https://github.com/pejonp/vbus/blob/master/dl2_httpmod_fhem.cfg 
|     |       | FHEM-Forum: https://forum.fhem.de/index.php/topic,10303.msg347411.html#msg347411
|0053 |  DL_3 |
|1001|DeltaSol_SLT| 11.02.2017
|1011|DeltaSol_SLT_WMZ| 11.02.2017
|1060|Vitosolic200_SD4|
|1065|Vitosolic200_WMZ1|
|1066|Vitosolic200_WMZ2|
|1059|DeltaThermHC_mini_Regler| 23.08.2016
|1121|DeltaSol_CS2| 18.03.2017
|1140|DeltaThermHC_mini_HK| 23.08.2016
|1240|Wagner_Sungo_100_Regler| 14.12.2017
|1241|Wagner_Sungo_100_WMZ1| 14.12.2017
|2211|DeltaSol_CS_Plus| 03.10.2016
|2231|Oranier_HK_Regler| 14.04.2017
|2232|Oranier_HK_WMZ1| 14.04.2017
|2251|DeltaSol_SL|
|2252|DeltaSol_SL_WMZ1| 21.02.2017
|2261|HRSolar_BASIC| 21.02.2017
|2262|HRSolar_BASIC_WMZ1| 21.02.2017
|2271|DeltaSol_SLL|09.11.2016 (https://forum.fhem.de/index.php/topic,10303.msg518538.html#msg518538)
|2272|DeltaSol_SLL_WMZ1|09.11.2016 (michaelfhem)
|4010|WMZ|
|4011|WMZ1| 11.09.2018
|4012|WMZ2| 11.09.2018
|4013|WMZ3| 11.09.2018
|4211|SKSC1/2|
|4212|DeltaSolC|
|4213|Sonnenkraft_SKSC1HE|19.01.2017
|4214|Sonnenkraft_SKSC2HE|19.01.2017
|4221|DeltaSol_BS_Plus|04.02.2017
|4278|DeltaSol_BS4|
|427B|DeltaSol_BS_2009|
|5251|Frischwasserregler| 15.01.2017
|5400|DeltaThermHC_Regler| 23.08.2016
|5410|DeltaThermHC_HK0| 23.08.2016
|5411|DeltaThermHC_HK1| 12.11.2016
|5412|DeltaThermHC_HK2| 12.11.2016
|5420|DeltaThermHC_WMZ0| 23.08.2016
|5421|DeltaThermHC_WMZ1| 18.02.2017
|5430|DeltaThermHC_MODUL0| 18.02.2017
|5431|DeltaThermHC_MODUL1| 18.02.2017
|5611|DeltaTherm_FK|
|6521|MSR65_1|
|7821|MSR65_1|
|6522|MSR65_2|
|7112|DeltaSol_BX_Plus_Regler| 03.04.2017
|7113|DeltaSol_BX_Plus_Module| 03.04.2017
|7121|DeltaSol_BX_Plus_Heizkreis| 03.04.2017
|7131|DeltaSol_BX_Plus_WMZ1| 03.04.2017
|7132|DeltaSol_BX_Plus_WMZ2| 11.08.2019
|7133|DeltaSol_BX_Plus_WMZ3| 11.08.2019
|7134|DeltaSol_BX_Plus_WMZ4| 11.08.2019
|7160|SKS3HE|
|7161|SKSC3HE_[HK1]|
|7162|SKSC3HE_[HK2]|
|7210|Sonnenkraft_SKSR1/2/3|26.2.2017
|7211|Sonnenkraft_SKSC3_[HK1]|26.2.2017
|7212|Sonnenkraft_SKSC3_[HK2]|26.2.2017
|7213|Sonnenkraft_SKSC3_[HK3]|26.2.2017
|7311|DeltaSol_M|
|7312|DeltaSol_M_HKM|
|7315|DeltaSol_M_Volumen|
|7316|DeltaSol_M_WMZ1|
|7317|DeltaSol_M_WMZ2|
|7321|Vitosolic200|  => funktioniert (selber im Einsatz)
|7326|Vitosolic200_WMZ1|  => funktioniert (selber im Einsatz)
|7327|Vitosolic200_WMZ2|  => funktioniert (selber im Einsatz)
|7331|SLR|
|7341|CitrinSLR_XT|
|7342|SLR XT-Erweiterungsmodul1| 15.01.2017
|7343|SLR XT-Erweiterungsmodul2| 15.01.2017
|7344|SLR XT-Erweiterungsmodul3| 15.01.2017
|7345|SLR XT-Erweiterungsmodul4| 15.01.2017
|7346|SLR XT-Erweiterungsmodul5| 15.01.2017
|7411|DeltaSol_ES|
|7421|DeltaSol_BX|
|7721|DeltaSolE_Regler|
|7722|DeltaSolE_WMZ|
|7731|DeltaSol S2/S3|20.11.2017
|7751|DiemasolC|
|7821|Cosmo_Multi_Regler|
|7822|Cosmo_Multi_WMZ|
|7E11|DeltaSol_MX_Regler|
|7E12|DeltaSol_MX_Module|
|7E21|DeltaSol_MX_Heizkreis|
|7E31|DeltaSol_MX_WMZ| angepaßt 03.04.2017


VBUS-Decoder

http://hobbyelektronik.org/w/index.php/VBus-Decoder

Hier ein Sketch zum auslesen einer RESOL DeltaSol über die seriele Schnittstelle.
https://github.com/ESP8266nu/ESPEasyPluginPlayground/blob/master/_P109_RESOL_DeltaSol_Pro.ino

In Kombination mit einem ESP8266 sicher eine gute und preiswerte Lösung. Beim fehlen einer serielen Schnittstelle könnte man den VBUS mit nachfolgender Schaltung nutzen. 

Einfache Schaltung für den lesenden Zugriff auf den VBUS: https://groups.google.com/forum/#!topic/resol-vbus/3CjZffK53ig

Quelle: https://forum.fhem.de/index.php/topic,10303.msg472373.html#msg472373

Im VBUS LAN Adapter Device wird das Password für den RESOL Lan-Adapter hinterlegt.
https://github.com/pejonp/vbus/blob/master/set%20Passwd%20VBUS.JPG
