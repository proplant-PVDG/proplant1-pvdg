
post_host = os.getenv("SERVER")
bzg = os.getenv("DESC")
portal_id = os.getenv("PORTALID")

alarm_host   = post_host
ipkg_url = "/ipkgs/"

PX = PX or ""

if string.find (post_host,"solaranlagen.wfgsha.de")~=nil then
  print ("Using /get_data.php and /get_alarm.php")
  log_url           = "/get_data.php"
  alarm_url         = "/get_alarm.php"
  log_urlWfgZaehler = "/get_data_power_meter.php"
else
  print ("Using /get_data.php and /get_alarm.php /get_alarmSendmail.php")
  log_url       = "/get_data.php"
  alarm_url     = "/get_alarm.php"
  mail_url      = "/get_email.php"
  config_url    = "/get_config.php"
end

anlagen_id = os.getenv("ALI") or "0000"
if master~="Sending" then
  anzahl_wechselrichter = tonumber(os.getenv("MASTERWRNUM") or os.getenv("WRN"))
  print("Anzahl WRs = "..anzahl_wechselrichter)
end

print("Anlagen-Id = "..anlagen_id)
alarmDir = PX.."/mnt/jffs2/sending/"
