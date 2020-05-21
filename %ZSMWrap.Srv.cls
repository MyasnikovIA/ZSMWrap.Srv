/// 
/// d ##class(%ZSMWrap.Srv).Start(6010)
/// <example>
///   d ##class(%ZSMWrap.Srv).Start(8228  , "C:\AppServ\www","DUBROVINO","/index.htm" )
///   d ##class(%ZSMWrap.Srv).Start(6010  , "C:\AppServ\www","user","/index.html" )
///   d ##class(%ZSMWrap.Srv).Start(6010  , "C:\AppCacheSrv\www","user","/index.html" )
///   d ##class(%ZSMWrap.Srv).Start(6010  , "D:\sirena\env","sirena","sirena/index.csp" )
///   d ##class(%ZSMWrap.Srv).Start(6010  , "E:\!5autoexport\myasnikovia\www","sirena","/index.html" )
///   d ##class(%ZSMWrap.Srv).Stop()
/// </example>
Class %ZSMWrap.Srv Extends %SYS.Task.Definition [ Language = cache ]
{

Property Port As %String [ InitialExpression = 6010 ];

Property Dir As %String [ InitialExpression = "C:\AppServ\www" ];

Property Page As %String [ InitialExpression = "/index.html" ];

Property NameSpace As %String [ InitialExpression = "user" ];

Parameter GlobalMessage = "^mtempZSMWrap.Srv.js";

Method OnTask() As %Status
{
   d ##class(%ZWeb.Srv).Start(..Port  , ..Dir,..NameSpace,..Page )    
   quit $$$OK
}

///  d ##class(%ZSMWrap.Srv).export()
ClassMethod export() As %Status
{
  d $system.OBJ.ExportUDL("%ZSMWrap.Srv.cls","C:\InterSystems\ZSMWrap.Srv\%ZSMWrap.Srv.cls")
  d $system.OBJ.ExportUDL("%ZSMWrap.RunJob.cls","C:\InterSystems\ZSMWrap.Srv\%ZSMWrap.RunJob.cls")
}

/// Остановить работу сервера
ClassMethod Stop(port As %Integer = 6010)
{
   s port=$g(port)
    if $l(port)>0 d
    . s ^%ZWebServerKill(port)=1
    .  S httprequest=##class(%Net.HttpRequest).%New()
    .  s httprequest.Server="127.0.0.1"
    .  s httprequest.Port=port
    .  s httprequest.Timeout=1
    .  d httprequest.Get("/")
    .  s httprequest=""
    . h 1
    . w !,"Server "_port_" stoped"
    e  d
    . s port=""
    . q:$d(^%ZWebServerCfg)
    . f  s port=$o(^%ZWebServerCfg(port))  q:port=""   d
    . .  s ^%ZWebServerKill(port)=1
    . .   S httprequest=##class(%Net.HttpRequest).%New()
    . .   s httprequest.Server="127.0.0.1"
    . .   s httprequest.Port=port
    . .   s httprequest.Timeout=1
    . .   d httprequest.Get("/")
    . .   s httprequest=""
    . .  h 1
    . .  w !,"Server "_port_" stoped"
    q
}

///  d ##class(%ZWeb.Server).Start(9229  , "C:\AppServ\www","USER","/index.html" , "main")
/// 
/// Запустить работу сервера
ClassMethod Start(port As %Integer = 6010, pathHost As %String = "C:\AppServ\www", NameSpaceDefault As %String = "USER", startPage As %String = "index.html")
{
     s methodDefault = "OnPage"
     k ^%ZWebServerKill(port)
     ; 63991
     w !,"Автор: Мясников Иван Александрович"
     w !,"Email: Miacom@mail.ru"
     w !
     ; if $p($h,",",1)>(63991+60+60+60) w !,"Льготный период использования закончился. Обратитесь к автору за продлением.",!
     s port = $G(port)  
     s TimeOut=3200
     s pathHost=$g(pathHost)
     s NameSpaceDefault=$g(NameSpaceDefault)
     s startPage=$g(startPage)
     s methodDefault=$g(methodDefault )
          if $d(^%ZWebServerCfg(port)) d
          .    d ..Stop(port)
          .    k ^%ZWebServerCfg(port)
          s ^%ZWebServerCfg(port)=$lb(port,TimeOut,pathHost,NameSpaceDefault, startPage,methodDefault)
     s cmd="cmd /c  start ""explorer.exe""  ""http://127.0.0.1:"_port_"/"_startPage_""""
     ; d $zf(-1,cmd,1)
     job ..startJob(port)
     w !,"Start server:"_port
     q
}

/// Работа сокет сервера в паралельном потоке.
/// Ожидание подключения и создание обработчика клиента в паралельном потоке
ClassMethod startJob(port)
{
     s port = $lg(^%ZWebServerCfg(port),1)  
     SET dev="|TCP|1"
     OPEN dev:(:port:"MA"):200
     s inData=""
     s indSrv=0
     s isEnd=0
     k ^%ZWebServerKill(port)
	 s oldNS = $zu(5)
	 d $zu(5,"%SYS") 
	 s LocAppName="" 
	 for {
	    s LocAppName=$o(^SYS("Security","ApplicationsD",LocAppName))
	    q:LocAppName="" 
	    s NameSpace=$lg(^SYS("Security","ApplicationsD",LocAppName),15)
	    s RootPath=$lg(^SYS("Security","ApplicationsD",LocAppName),17)
	    s TimeOut = $lg(^SYS("Security","ApplicationsD",LocAppName),23)
	    s Secur = $lg(^SYS("Security","ApplicationsD",LocAppName),2)
	    s ^%ZWebServerCfg(port,"Applications",LocAppName)=$lb(NameSpace,RootPath,TimeOut,Secur )
	 }
     d $zu(5,oldNS)
     k @..#GlobalMessage
     For  USE dev  READ inData q:isEnd=1  Do:$T
     .  if $d(^%ZWebServerKill(port))   s isEnd=1
     .  USE dev  
     .  Job ..childVar(port):(:17::)  ; Concurrent server bit is on
     .  If $ZCHILD=0 w " Server can't create new JOB!"
     Close dev   
     k ^%ZWebServerKill(port)
     Quit
}

/// 
/// Процедура обработки клиентского запроса
/// 
ClassMethod childVar(port)
{
   s TimeOut=$lg(^%ZWebServerCfg(port),2)
   s pathHost=$lg(^%ZWebServerCfg(port),3)
   s NameSpaceDefault=$lg(^%ZWebServerCfg(port),4)
   s startPage=$lg(^%ZWebServerCfg(port),5)
   s methodDefault=$lg(^%ZWebServerCfg(port),6)
   zn NameSpaceDefault ; переключаем область имен
   s numPac=0
   s isCloseChaild=0 
   s SocketTempIndex=0
   USE $ZUTIL(53):(::"M")
   s I=$ZU(111,0)
   s ip=$A(I,1)_"."_$A(I,2)_"."_$A(I,3)_"."_$A(I,4) ; _":"_($A(I,5)*256+$A(I,6))
   ; s ip=$ZU(67, 15, $job)
   s countEnter=0
   s numPack=0
   s isEndTitle=0 
   ; Инициализируем переменную для работы в CSP классах
   s %request=##class(%CSP.Request).%New()
   s %response=##class(%CSP.Response).%New()
   D %response.SetHeader("Content-Type","text/html")   
   d %request.InsertCgiEnv("Cache version",$$GetVersion^%apiOBJ())
   d %request.InsertCgiEnv("LOCAL_PATH",pathHost)
   d %request.InsertCgiEnv("QUERY_PAGE",startPage)
   d %request.InsertCgiEnv("CLIENT_IP",ip)
   d %request.InsertCgiEnv("REMOTE_ADDR",$ZU(67, 15, $job))

   s request=##class(%ZEN.proxyObject).%New()
   s request.%data("Cache version")= $$GetVersion^%apiOBJ()	     
   s request.%data("CLIENT_IP")=ip   
   s request.%data("REMOTE_ADDR")= $ZU(67, 15, $job)     
   s request.%data("Content-Type")="text/html"
   s request.%data("CharSet")="UTF8"
   
   s %response.CharSet="UTF8"
   ; s %response.CharSet="CP1251"
   s %SYSLOG=1
   s %CSPsc=1
   ; Set %session.AppTimeout = 3600 
   s isTerminal=0
   s isWebSocket=0
   s isWebSocketKey=""
   s WebSocketVer=-1
   s FallLoad=0
   For  Q:((isCloseChaild=1)||($T=1)||(isTerminal=1) )  d
   .  If $T=1 s isCloseChaild=1 
   .  // Если терминальный запрос, тогда уничтожаем этот процесс
   .  if isTerminal=1 d $zu(4,$job)
   .  if isEndTitle=0 {
   .     S dev=$ZUTIL(53)  
   .     USE dev:(::"M")  
   .     READ inData:1
   .     ; s ^debug($job,numPack)=inData
   .     s numPack=numPack+1
   .        ; Если в первой строке нет слов GET или POST , тогда запрос произведен из терминала
   .        if numPack=1  if $l(inData,"GET /")=1  ,$l(inData,"POST /")=1    s isTerminal=1 q
   .        ; Меняем кодировку входных данных(разкоментируется при необходимости, в зовисимости от версии cache')
   .        s inData= $ZCVT(inData,"I","URL")
   .        ; s inData= $ZCVT(inData,"I","UTF8")
   .
   .      if numPack=1 d ; обработка первой строки HTML запроса
   .      .   if $l(inData,"GET /")=2   d 
   .      .   .  s zapros=$p(inData,"GET /",2)
   .      .   .  d %request.InsertCgiEnv("REQUEST_METHOD","GET")
   .      .   .  s request.%data("REQUEST_METHOD")="GET"   
   .      .   .  s zapros=$p(zapros," HTTP/",1)   , isGet=1 ,TypeZapros="GET"   
   .      .   if $l(inData,"POST /")=2  d 
   .      .   .  s zapros=$p(inData,"POST /",2)   
   .      .   .  d %request.InsertCgiEnv("REQUEST_METHOD","POST")
   .      .   .  s request.%data("REQUEST_METHOD")="POST"   
   .      .   .  s zapros=$p(zapros," HTTP/",1)   , isPost=1 ,TypeZapros="POST" 
   .      .  
   .      .   if $l(zapros)=0 s zapros=startPage
   .      .   if $l($p(zapros,"?",1))=0   s zapros=startPage_"/"_zapros
   .      .    ; если GET запрос и присутствует один символ "?" тогда заменяем его на "/?"
   .      .   if $l(zapros,"/?")=1 , $l(zapros,"?")'=1 , $e(zapros, $l( $p(zapros,"?",1)),$l( $p(zapros,"?",1)))'="/"   s zapros=$e(zapros,1,$l( $p(zapros,"?",1)))_"/?"_$e(zapros,$l( $p(zapros,"?",1))+2,$l(zapros))
   .      .        if $l(zapros,"csp/broker/cspxmlhttp.js")=2 {
   .      .   	      ; s zapros="%ZHTML.CacheLib.cls"   
   .      .   	      s FallLoad=1
   .      .        }
   .      .        if $l(zapros,"csp/broker/cspbroker.js")=2 {
   .      .   	      s zapros="%ZHTML.RunJob.cls"   
   .      .        }
   .      .   s request.%data("PATH_TRANSLATED")=$tr(pathHost_"/"_zapros,"/","\")
   .      .   s request.%data("QUERY_STRING")=zapros  
   .      .   s request.%data("SERVER_ADDR")=$p(ip,":",1)
   .      .   s:$l(zapros)=0 request.%data("REQUEST_URI")=zapros  
   .      .   Do %request.InsertCgiEnv("PATH_TRANSLATED",$tr(pathHost_"/"_zapros,"/","\"))
   .      .   Do %request.InsertCgiEnv("QUERY_STRING",zapros)
   .      .   Do %request.InsertCgiEnv("SERVER_ADDR",$p(ip,":",1))   
   .      .   Do %request.Set("clientip",ip) 
   .      .   Do:$l(zapros)=0 %request.InsertCgiEnv("REQUEST_URI",zapros)   
   .      .   q
   .   
   . 
   .     if $l(inData,":") >1 d
   .     .  s nam=$p(inData,": ",1)
   .     .  s val=$p(inData,": ",2)
   .     .  Do %request.Set(nam,val)    
   .     .  do %request.InsertCgiEnv($ZCVT(nam,"U"),val)
   .     .  s request.%data($ZCVT(nam,"U"))=val
   .     .  Do:nam="Referer" %request.InsertCgiEnv("HTTP_REFERER",val)
   .     .  s:nam="Referer" request.%data("HTTP_REFERER")=val
   .    
   .     ; проверяем наличие трех Enter (это признак окончания заголовка html запроса)
   .       if $l(inData)=0 s countEnter=countEnter+1
   .       if countEnter=2 s isEndTitle=1 
   .       if $l(inData)>0 s countEnter=0
   .       q
   .  }
   .
   .  ; читаем тело POST запроса 
   .  if $l(%request.GetCgiEnv("CONTENT-LENGTH"))'=0 {
   .       s lenPost=%request.GetCgiEnv("CONTENT-LENGTH")
   .       d %request.InsertCgiEnv("CONTENT_LENGTH",lenPost)
   .       s request.%data("CONTENT_LENGTH")=lenPost 
   .       ; s BodyPost=##class(%CSP.BinaryStream).%New()
   .       ; s %request.Content=##class(%CSP.BinaryStream).%New()
   .       Set %request.Content=##class(%GlobalCharacterStream).%New()
   .       s indPostTeloZaprosa=0
   .       s isCloseChaildPost=0
   .       ;  while (isCloseChaildPost=0&&lenPost>0) {
   .       while (lenPost>0) {  
   .          If $T=1 s isCloseChaildPost=1
   .          USE $ZUTIL(53):(::"M")  
   .          READ inData:0.01
   .          s lenPost=lenPost-$l(inData)
   .          s indPostTeloZaprosa=indPostTeloZaprosa+1
   .          s ^%WebPost($JOB,indPostTeloZaprosa)=inData
   .          ; s ^debug("POST",indPostTeloZaprosa)=inData
   .          ; s ^debug("POST",indPostTeloZaprosa,0)=$l(inData)
   .          d %request.Content.Write(inData)
   .          s request.%data("Content")=inData
   .          ; s inData= $ZCVT(inData,"I","URL")
   .          ; Разбираем параметры из первой строки тела post запроса
   .          if $l(inData,"=")>1 {
   .          for  {
   .               s nam=$e(inData,1,$l($p(inData,"=",1)))
   .               s inData=$e(inData,$l(nam)+1,$l(inData))
   .               s val=$e(inData,2,$l($p(inData,"&",1)))
   .               s inData=$e(inData,$l(val)+3,$l(inData))
   .               if $l(val)>32760 { ; Переделать !!!!!
   .                  s obj=##class(%CSP.CharacterStream).%New()
   .                  d obj.Write(val)
   .                  Do %request.Set(nam,obj)  s request.%data(nam)=obj
   .               } else {
   .                  Do %request.Set(nam,val)  s request.%data(nam)=obj
   .               }
   .               q:$l(inData)=0
   .               q:$l(inData,"=")=1
   .            }
   .          }
   .       }
   .       d %request.Content.Rewind()
   .       ;   for  {
   .       ;     q:%request.Content.AtEnd;
   .       ;     s ^deb=%request.Content.Read(32000)
   .       ;   }
   .       s isCloseChaild=1  
   .       q
   .    }
   .    s isCloseChaild=1 
   .    q
   ;
   ; обрабатываем терминальный Socket запрос 
   if isTerminal=1 {
     ; s ^debug($job,numPack)=inData
     ; For  Q:((isCloseChaild=1)||($T=1)||(isEndTitle=1) )  d
     ; .    If $T=1 s isCloseChaild=1 k ^debug($job) q
     ; .    USE $ZUTIL(53):(::"M")  
     ; .    READ inData
     ; .    if inData="exit" s isCloseChaild=1  k ^debug($job) q
     ; .    s numPack=numPack+1
     ; .    s ^debug($job,numPack)=inData
   }
  ;  если обрабатываем  терминальный запрос , тогда выходим
    q:isTerminal=1
  ;
  ; Запоминаем расширение файла как тип содержимого
    s typ=$p(zapros ,".", $l(zapros,"."))
    s typ=$p(typ,"/?",1)
    s typ=$p(typ,"/",1)
    d %request.InsertCgiEnv("CONTENT_TYP",typ)
    s request.%data("CONTENT_TYP")=..ContentType("."_typ)
  ; 
  ; USE $ZUTIL(53):(::"M") w "HTTP/1.1 200",$c(13,10),"Content-type: text/plain","",$c(13,10),"Connection: close"_$c(13,10,13,10)
  ; Разбираем Куки в параметры
  s request=..ParseСookie(.request)
  ; Разбираем параметры из URL строки 
  s request=..ParseParam(.request)
 
        
  ;  Если етсьпараметр "typ" тогда меняем тип содержимого
  if $d(request.%data("typ"))  s request.%data("CONTENT_TYP")=..ContentType("."_request.%data("typ"))

  s RootPath=pathHost	  
  s UrlName=request.%data("QUERY_PAGE") 
  s AppName=$SYSTEM.CSP.GetAppName(UrlName)
  s ClassName=""
  if AppName'=""{
	 s AppLoc="/"_$e(AppName,1,$l(AppName)-1)
     if $d(^%ZWebServerCfg(port,"Applications",AppLoc)){
     	s app=^%ZWebServerCfg(port,"Applications",AppLoc)
     	s NameSpace = $lg(^%ZWebServerCfg(port,"Applications",AppLoc),1)
     	s RootPath  = $lg(^%ZWebServerCfg(port,"Applications",AppLoc),2)
     	s TimeOut   = $lg(^%ZWebServerCfg(port,"Applications",AppLoc),3)
     	s Secur     = $lg(^%ZWebServerCfg(port,"Applications",AppLoc),4)
     	d $zu(5,NameSpace)
		s ClassName=$System.CSP.GetClassName("/"_UrlName)
		    if ClassName="" {
		       if $l(UrlName)>$l(AppName){
		          if $e(UrlName,1,$l(AppName))=AppName {
		              s ClassName=$e(UrlName,$l(AppName)+1,$l(UrlName))
		          }
		       }
        }     	
     }
  }
  s PathFile =RootPath_"/"_request.%data("QUERY_PAGE")
  s rassh= $ZCVT($p(PathFile ,".", $l(PathFile,".")),"L")
  s request.%data("expansion")=rassh
  s request.%data("PathFile")=PathFile
  s request.%data("AppName")=AppName
  s request.%data("ClassName")= $e(request.%data("QUERY_STRING"),$l(AppName)+1 ,$l(request.%data("QUERY_STRING")))
  if $l(request.%data("ClassName"),"/?")>1{
	  s request.%data("ClassName")=$p(request.%data("ClassName"),"/?",1)
  }
  s request.%data("RootPath")=RootPath
  s request.%data("NameSpace")=$zu(5)
  
       s %ClientIP=ip
       s %ProcessID="test"
       if '$d(@..#GlobalMessage@(%ClientIP,%ProcessID)){
          job ..ExecRunJobMethod(%ClientIP,%ProcessID)
	      s LastJobId=$zchild
	      s @..#GlobalMessage@(%ClientIP,%ProcessID)=LastJobId
       }else{
	      s LastJobId=@..#GlobalMessage@(%ClientIP,%ProcessID)
	      if '$DATA(^$JOB(LastJobId)) {
		    k @..#GlobalMessage@(%ClientIP,%ProcessID)
	      	job ..ExecRunJobMethod(%ClientIP,%ProcessID)
	      	s LastJobId=$zchild
	      	s @..#GlobalMessage@(%ClientIP,%ProcessID)=LastJobId
	      }
       }
       if (request.%data("AppName")'="")&&($l("mac|html|css|cls|txt|csp",rassh)>1){
	       set @..#GlobalMessage@(%ClientIP,%ProcessID,"Request")=..GetJsonRequest(request)
	       USE $ZUTIL(53):(::"M") 
	       ; w "HTTP/1.1 200",$c(13,10)
	       ; w "Content-type: "_..ContentType("."_%request.GetCgiEnv("CONTENT_TYP"))_"; charset="_%response.CharSet,$c(13,10)
	       ; w "Connection: close"_$c(13,10,13,10)
		   do $system.Event.Signal(LastJobId,$job)         // передаем сигнал на пробуждения пользовательского процесса	
	       s childJob=$list($system.Event.WaitMsg(), 2)    // ожидаем ответа из процесса (подвещиваем процесс)
		   if $d(^mtempZWebServerBufferRunJobOneDrawConsole(childJob,"BUFF")){
	 		  s line=^mtempZWebServerBufferRunJobOneDrawConsole(childJob,"BUFF")
	 		  s ind=""
			  for { 
			    s ind=$o(^mtempZWebServerBufferRunJobOneDrawConsole(childJob,"BUFF",ind))
			    q:ind=""
			    w ^mtempZWebServerBufferRunJobOneDrawConsole(childJob,"BUFF",ind)
			  }
		      k ^mtempZWebServerBufferRunJobOneDrawConsole(childJob)
		   }
	       d ..clsConnect()
	       q
      }
	  
	  if ..GetRawHtml(request)=1     d ..clsConnect() q
          
    
     ; 
     ;  Запрашиваемый ресурс не найден
        USE $ZUTIL(53):(::"M") w "HTTP/1.1 400",$c(13,10)
        w "Content-type: text/plain"_"; charset="_request.%data("CharSet"),$c(13,10)
        w "Connection: close"_$c(13,10,13,10)
        w !,"=================================" 
        w !,"=             NoPage            ="  
        w !,"=================================" 
        w !,!
        zw request
        w !,!
        w %request.GetCgiEnv("QUERY_PAGE"),!
        w PathFileLocal,!
        w PathFile,!
        w rassh,!
        w !,"OK"
        zw 
        d ..clsConnect()
        q    
      
      q
}

ClassMethod ExecRunJobMethod(ip = "127.0.0.1", ProcessID = "test") [ ProcedureBlock = 0 ]
{
     s %ProcessID="test"
     s %ClientIP=ip
     k ip,ProcessID
	 s ^deb=$job
     for {	
         s %ParentJobProcess=$list($system.Event.WaitMsg(), 2) // ожидаем ответа из процесса родителя
	     s %request=##class(%CSP.Request).%New()  
		 if $d(@..#GlobalMessage@(%ClientIP,%ProcessID,"Request")){
			s tmp=@..#GlobalMessage@(%ClientIP,%ProcessID,"Request")
			k @..#GlobalMessage@(%ClientIP,%ProcessID,"Request")
		    do ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(tmp,,.%request,1)
		    k tmp
	     }
	     d ..DrawBegin()	 
	     s isDraw=0
	     if %request.%data("expansion")="mac"{
            if ##class(%Routine).Exists(%request.%data("ClassName"))=1 {
	           d ..DrawMac(%request.%data("ClassName"))
    	       s isDraw=1
            }
         }
         if %request.%data("expansion")="cls"{
           s isDraw=..GetClsHtml(%request.%data("ClassName"))
         }
         if %request.%data("expansion")="csp"{
	       s cls=$System.CSP.GetClassName("/"_%request.%data("QUERY_PAGE"))
	       if $l(cls)>0{
              if (($zObjClassMethod("%CompiledClass","%ExistsId",cls)'=1) && (##class(%File).Exists(rawFileName)=1)){
	              d ..DrawEnd()
	              d $SYSTEM.CSP.LoadPage( %request.%data("PathFile"),"ck")
	              d ..DrawBegin()
              }    
              s %request.%data("ClassName")=cls_".cls"
              s isDraw=..GetClsHtml(%request.%data("ClassName"))
	       }
         }
         if ( (%request.%data("expansion")="html")
            ||(%request.%data("expansion")="htm")
            ||(%request.%data("expansion")="css")
            ||(%request.%data("expansion")="js")
            ||(%request.%data("expansion")="txt")
            ){
	     	s isDraw=..GetRawHtml(request)
         }
         if isDraw=0{
	       w "HTTP/1.1 400",$c(13,10)
	       w "Content-type: text/html",$c(13,10)
	       w "Connection: close"_$c(13,10,13,10)
	       w "Content not found",!
	       w "<pre>"
	       zw %request
	       w "</pre>"
         }
     	 d ..DrawEnd()
     	 d $system.Event.Signal(%ParentJobProcess,$job)        // передаем сигнал обратно
     }
}

/// Закрытие соединения , очистка переменных (глобалов)
ClassMethod clsConnect()
{
   ; Close dev  
   ; w *-1,!
   w *-2,$c(13,10)
   s isCloseChaild=0   
   k ^%WebPost($JOB)
   q
}

/// 
///  разбираем Сookie
ClassMethod ParseСookie(request)
{
   q:'$d(request.%data("COOKIE")) request
   q:$l(request.%data("COOKIE"))=0 request
   s arg=request.%data("COOKIE")
   for ind=1:1:$l(arg,"; ")  d
   .    s tmp= $p(arg,"; ",1)
   .    if $l(tmp,"=")=2  d
   .    .  s ParamName=$p(tmp,"=",1)
   .    .  s zndch=$p(tmp,"=",2)
   .    e  d
   .    .   s ParamName=$p(tmp,"=",1)
   .    .   s zndch=""
   .    do request.%data(ParamName,zndch) 
   .    ; do %request.InsertCookie(ParamName,zndch)
   .    ; s ^deb($job,ParamName)=zndch
   s ParamName=""
   q request
}

/// 
/// разбираем Параметры в строке URL запроса 
ClassMethod ParseParam(request)
{
   ;
   ;  разбираем Параметры в строке запроса
   if $d(request.%data("QUERY_STRING")) d
   .     s arg=request.%data("QUERY_STRING")
   .     s request.%data("QUERY_PAGE")=$p(arg,"/?",1)
   .     
   .     if $l(arg,"?")>1  d
   .     .  if $l($p(arg,"?",1))=0  d
   .     .  .  s arg="/"_arg
   .     s arg=$p(arg,"/?",2)
   .     if $l(arg)>0  d
   .     .  s indParam=0
   .     .  for   q:arg=""   d
   .     .  .    s tmp= $p(arg,"&",1)
   .     .  .    if $l(tmp,"=")=2  d
   .     .  .    .  s ParamName=$p(tmp,"=",1)
   .     .  .    .  s zndch=$p(tmp,"=",2)
   .     .  .    e  d
   .     .  .    .  ; s indParam=indParam+1
   .     .  .    .  ; s ParamName="param"_indParam
   .     .  .    .  ; s zndch=$p(tmp,"=",1)
   .     .  .    .  s ParamName=$p(tmp,"=",1)
   .     .  .    .  s zndch=""
   .     .  .    s arg=$p(arg ,tmp,2)
   .     .  .    if $l(arg)>1 s arg=$e( arg,2,$l(arg))
   .     .  .    q:ParamName=""
   .     .  .    ; s ParamName = $ZCVT(ParamName,"L")
   .     .  .    s request.%data(ParamName)=zndch
   .     .  .    s ParamName=""
   q request
}

/// Определить MIME тип по имени файла
ClassMethod ContentType(FileName) As %String
{
     s rashirenie=$p(FileName ,".", $l(FileName,"."))
     s rashirenie= $ZCVT(rashirenie,"l")
     q:rashirenie="css" "text/css"
     q:rashirenie="js" "application/x-javascript"
     q:rashirenie="xml" "text/xml"
     q:rashirenie="dtd" "text/xml"
   ; -------------------------------------
     q:rashirenie="txt" "text/plain"
     q:rashirenie="inf" "text/plain"
     q:rashirenie="nfo" "text/plain"
   ; -------------------------------------
     q:rashirenie="html" "text/html"
     q:rashirenie="csp" "text/html"
     q:rashirenie="htm" "text/html"
     q:rashirenie="shtml" "text/html"
     q:rashirenie="shtm" "text/html"
     q:rashirenie="stm" "text/html"
     q:rashirenie="sht" "text/html"
     q:rashirenie="sht" "text/html"
     q:rashirenie="csp" "text/html"
     q:rashirenie="mac" "text/html"
     q:rashirenie="cls" "text/html"
     q:rashirenie="jpg" "image/jpeg"

     ; q:rashirenie="cos" "text/html" ; каше обжект скрипт
   ; -------------------------------------
     q:rashirenie="mpeg" "video/mpeg"
     q:rashirenie="mpg" "video/mpeg"
     q:rashirenie="mpe" "video/mpeg"
   ; -------------------------------------
     q:rashirenie="ai" "application/postscript"
     q:rashirenie="zip" "application/zip"
                  q:rashirenie="zsh" "text/x-script.zsh"
                  q:rashirenie="x-png" "image/png"
                  q:rashirenie="xls" "application/x-excel"
                  q:rashirenie="xlm" "application/excel"
                  q:rashirenie="wav" "audio/x-wav"
                  q:rashirenie="txt" "text/plain"
                  q:rashirenie="tiff" "image/tiff"
                  q:rashirenie="tif" "image/x-tiff"
                  q:rashirenie="text" "text/plain"
                  q:rashirenie="swf" "application/x-shockwave-flash"
                  q:rashirenie="sprite" "application/x-sprite"
                  q:rashirenie="smil" "application/smil"
                  q:rashirenie="sh" "text/x-script.sh"
                  q:rashirenie="rtx" "text/richtext"
                  q:rashirenie="rtf" "text/richtext"
                  q:rashirenie="pyc" "application/x-bytecode.python"
                  q:rashirenie="py" "text/x-script.phyton"
                  q:rashirenie="png" "image/png"
                  q:rashirenie="pic" "image/pict"
                  q:rashirenie="mp3" "video/mpeg"
                  q:rashirenie="mp2" "video/mpeg"
                  q:rashirenie="movie" "video/x-sgi-movie"
                  q:rashirenie="mov" "video/quicktime"
                  q:rashirenie="mjpg" "video/x-motion-jpeg"
                  q:rashirenie="mime" "www/mime"
                  q:rashirenie="mif" "application/x-mif"
                  q:rashirenie="midi" "audio/midi"
                  q:rashirenie="js" "application/javascript"
                  q:rashirenie="jpeg" "image/jpeg"
                  q:rashirenie="jps" "image/x-jps"
                  q:rashirenie="jam" "audio/x-jam"
                  q:rashirenie="jav" "text/plain"
                  q:rashirenie="java" "text/x-java-source"
                  q:rashirenie="htm" "text/html"
                  q:rashirenie="html" "text/html"
                  q:rashirenie="gzip" "application/x-gzip"
                  q:rashirenie="gif" "image/gif"
                  q:rashirenie="gl" "video/gl"
                  q:rashirenie="csh" "text/x-script.csh"
                  q:rashirenie="css" "text/css"
                  q:rashirenie="bsh" "application/x-bsh"
                  q:rashirenie="bz" "application/x-bzip"
                  q:rashirenie="bz2" "application/x-bzip2"
                  q:rashirenie="c" "text/plain"
                  q:rashirenie="c++" "text/plain"
                  q:rashirenie="cat" "application/vnd.ms-pki.seccat"
                  q:rashirenie="cc" "text/plain"
                  q:rashirenie="htmls" "text/html"
                  q:rashirenie="bmp" "image/bmp"
                  q:rashirenie="bm" "image/bmp"
                  q:rashirenie="avi" "video/avi"
                  q:rashirenie="avs" "video/avs-video"
                  q:rashirenie="au" "audio/basic"
                  q:rashirenie="arj" "application/arj"
                  q:rashirenie="art" "image/x-jg"
                  q:rashirenie="asf" "video/x-ms-asf"
                  q:rashirenie="asm" "text/x-asm"
                  q:rashirenie="asp" "text/asp"
     q "application/octet-stream"
}

ClassMethod redirects() [ Internal, ProcedureBlock = 0 ]
{
wstr(s)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")=$get(^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF"),0)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF",$i( ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF") ))=s          q
wchr(c)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")=$get(^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF"),0)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF",$i( ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF") ))=$c(c)      q
wnl      s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")=$get(^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF"),0)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF",$i( ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF") ))=$$$NL      q
wff      s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")=$get(^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF"),0)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF",$i( ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF") ))=$c(12)     q
wtab(s)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")=$get(^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF"),0)  s ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF",$i( ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF") ))=s          q
}

ClassMethod DrawBegin() [ ProcedureBlock = 1 ]
{
	k ^mtempZWebServerBufferRunJobOneDrawConsole($job,"BUFF")
	s %LastIO=$IO
    u %LastIO::("^"_$zn)
    d ##class(%Device).ReDirectIO($$$YES)
}

ClassMethod DrawEnd()
{
 	d ##class(%Device).ReDirectIO($$$NO)
    u %LastIO
}

ClassMethod GetJsonRequest(request) As %String
{
        k ^SPOOL($job)
        O 2:($job)
        U 2:($job)
        do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(request,,,"aelotw")	
        c 2:($job)
        if $d(%request.CgiEnvs("Cache version")) {USE $ZUTIL(53):(::"M")}else{u 0}
        s resul=""
        s indexSPOOL=""
        for
        {  
           s indexSPOOL=$o(^SPOOL($job,indexSPOOL)) 
           q:indexSPOOL=""   
           s indexSPOOL2=indexSPOOL s indexSPOOL2=$o(^SPOOL($job,indexSPOOL2))
           if indexSPOOL2'="" 
           {
	          s str=^SPOOL($job,indexSPOOL)
	          s resul=resul_str
           }
        }
        s resul=$REPLACE(resul,$c(13,10,9,9),"")
        s resul=$REPLACE(resul,$c(13,10,9),"")
        s resul=$REPLACE(resul,"}, {","},{")
        s resul=$REPLACE(resul,"[ {","[{")
        s resul=$REPLACE(resul,"} ]","}]")
        s resul=$REPLACE(resul,"}"_$c(13,10)_"]","}]")
        s resul=$REPLACE(resul,$c(13,10)_"}","}")
        k ^SPOOL($job)
        q resul
}

/// Отправить клиенту файл с жесткого диска
ClassMethod GetRawHtml(request) As %Boolean
{
  // Замена пути к Cache библиотекам JS    
  //     <script  type="text/javascript" src="/csp/broker/cspxmlhttp.js"></script>
  //     <script  type="text/javascript" src="/csp/broker/cspbroker.js"></script>
  s rawFileName= request.%data("PathFile")
  s glHtml="^mtempRawHtmlFile"
  s list="js,html,htm,csp,css"
  s rashirenie=request.%data("expansion")
  s typ=request.%data("CONTENT_TYP")
  s file = ##class(%File).%New(rawFileName)
  s ReadFileGlobal=1
  // Если клобала с ресурсом нет, тогда создаем его
  if '$d(@glHtml@(rawFileName)) {
	  s ReadFileGlobal=0
  }else{ 
      ; если дата создания не соответствует дате в глобале, тогда перезагружаем глобал
      if $lg(@glHtml@(rawFileName),2)'=file.DateCreated  s ReadFileGlobal=0 k @glHtml@(rawFileName)
      ; если дата модификации не соответствует дате в глобале, тогда перезагружаем глобал
      if $lg(@glHtml@(rawFileName),3)'=file.DateModified s ReadFileGlobal=0 k @glHtml@(rawFileName)
      ; Если размер файла не соответствует файлу в глобеле
      if $lg(@glHtml@(rawFileName),4)'=file.Size s ReadFileGlobal=0 k @glHtml@(rawFileName)
  }
  if ReadFileGlobal=0 {
    ///  Передаем RAW файл из каталога директории 
    if ##class(%File).Exists(rawFileName)=1 {
      ; старый вариант получения расширения
      ; s rashirenie=$ZCVT($p(rawFileName ,".", $l(rawFileName,".")),"L")   
      ; Новый вариант в строке запроса можно указать тип ответа Пример: http://localhost:6010/csp/user/User.CacheLibTest.cls/?typ=jpg
      w "HTTP/1.1 200",$c(13,10)
      w "Content-type: "_request.%data("CONTENT_TYP")_"; "_request.%data("CharSet"),$c(13,10)
      w "Connection: close"_$c(13,10,13,10)
      S stream=##class(%FileBinaryStream).%New()
      S stream.Filename=rawFileName 
      s numLine=0
      s @glHtml@(rawFileName)=$lb(numLine,file.DateCreated,file.DateModified , file.Size,0)
      if $l(list,rashirenie)=1 {
         While 'stream.AtEnd  {
	       s numLine=numLine+1
	       s html=stream.Read(32000)
           s @glHtml@(rawFileName,numLine)=html
           s $LI(@glHtml@(rawFileName),1)=numLine
           s $LI(@glHtml@(rawFileName),5)=$Lg(@glHtml@(rawFileName),5)+$l(html)
           w html
         }
      }else{
        if typ["html" {
            /*
            w "<script language='JavaScript'>var request={""TIME"":"""_$h_""""
            s ind=""
            for {
	          s ind=$o(request.%data(ind))
	          q:ind=""  
	          w ","""_$ZCVT(ind,"O","JS")_""":"""_$ZCVT(request.%data(ind),"O","JS")_""""
            }
            w "}</script>",!
            */
            if $zObjClassMethod("%CompiledClass","%ExistsId","%ZSMWrap.RunJob")=1 {
               w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>",!
            }
            if $zObjClassMethod("%CompiledClass","%ExistsId","%ZSMWrap.RunJob")=1 {
               w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>",!
            }
        } 
        While 'stream.AtEnd  {
          s numLine=numLine+1
          s html=stream.Read(32000)
          s @glHtml@(rawFileName,numLine)=html
          s $LI(@glHtml@(rawFileName),1)=numLine
          s $LI(@glHtml@(rawFileName),5)=$Lg(@glHtml@(rawFileName),5)+$l(html)
          d ..ExecFrag(html,"/*(",")*/") 
        }
      }
      d stream.%Close()
      s stream=""
      s file =""
      q 1
    }
    q 0
  }else{
      w "HTTP/1.1 200",$c(13,10)
      w "Content-type: "_request.%data("CONTENT_TYP")_"; "_request.%data("CharSet"),$c(13,10)
      w "Connection: close"_$c(13,10,13,10)
	  if $l(list,rashirenie)=1 {  
          s numLine=""
         for {
	       s numLine=$o(@glHtml@(rawFileName,numLine))
	       q:numLine=""  
           s html=@glHtml@(rawFileName,numLine)
           w html
         }
      }else{
        if typ["html" {
           /*
            w "<script language='JavaScript'>var request={""TIME"":"""_$h_""""
            s ind=""
            for {
	          s ind=$o(request.%data(ind))
	          q:ind=""  
	          w ","""_$ZCVT(ind,"O","JS")_""":"""_$ZCVT(request.%data(ind),"O","JS")_""""
            }
            w "}</script>",!
            */
          ; if $zObjClassMethod("%CompiledClass","%ExistsId","%ZSMWrap.RunJob")=1 {
          ;    w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>",!
          ; }
          if $zObjClassMethod("%CompiledClass","%ExistsId","%ZSMWrap.RunJob")=1 {
             w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>",!
          }
        } 
         s numLine="" 
         for {
	       s numLine=$o(@glHtml@(rawFileName,numLine))
	       q:numLine=""  
           s html=@glHtml@(rawFileName,numLine)
           d ..ExecFrag(html,"/*(",")*/") 
         }
      }
      s file =""  k file
      q 1
  }
  s file =""  k file
  q 0
}

/// Метод разбивки исходного текста на Cache` код и HTML текст
ClassMethod ExecFrag(SrcCode = "", Beg = "", End = "") [ ProcedureBlock = 0 ]
{
     q:SrcCode=""   
     q:Beg=""    
     q:End=""    
     for ExecFragInd=1:1:$l(SrcCode,End){ 
        s ^||tmp=$p(SrcCode,End,ExecFragInd) 
        w $p(^||tmp,Beg,1)   
        TRY {     x $p(^||tmp,Beg,2)    } CATCH ErrorHandle {    zw ErrorHandle  }    
     }
}

ClassMethod DrawMac(MacName) As %Boolean
{
    q:##class(%Routine).Exists(MacName)=0 
    if $zcvt($e(MacName,$l(MacName)-$l("mac"),$l(MacName)) ,"L")=".mac" {
        s MacName=$e(MacName,1,$l(MacName)-$l(".mac"))          
    }
 ;   if ##class(%Routine).Exists(MacName)=0 
 ;   {
 ;     k ^deb
 ;     s isFoundMac=0
 ;     s res=##class(%ResultSet).%New("%Library.Routine:RoutineList")
 ;     d res.Execute("*.MAC,*.INT")
 ;     for  q:'res.Next()   q:isFoundMac=1   d
 ;     .  q:$zcvt(res.Get("Name"),"L")'=$zcvt(MacName,"L")
 ;     .  s isFoundMac=1, MacName=res.Get("Name")
 ;     .  s ^deb(res.Get("Name"))=1
 ;     q:isFoundMac=0 0
 ;   }
    s isMacMethod=0    
    s isMacPreMethod=0 
    s MacMethod="OnPage"       
    s MacPreMethod="OnPreHTTP" 
    s readRut=##class(%Routine).%New(MacName)
    s IndParam=""
    s isFoundLabel=0
    for
    {
        q:readRut.AtEnd
        s str=readRut.ReadLine()
        if $l(str)>0,$e(str,1,1)'=" "
        {
          s namesTRING=$e(str,1,$l($p(str," ",1)))
          s NameMethod=$p(namesTRING,"(",1)
          if $ZCVT(NameMethod,"L")=$ZCVT(MacMethod,"L")
          {   s MacMethod=NameMethod
              s isMacMethod=1
          }
          if $ZCVT(NameMethod,"L")=$ZCVT(MacPreMethod,"L")
          {   s MacPreMethod=NameMethod
              s isMacPreMethod=1
          }
        }
        if isMacMethod=1,isMacPreMethod=1 q
     }
     Do readRut.%Close()
     s $ztrap="ErrPre2"
     if isMacPreMethod=1 {
        x " d "_MacPreMethod_"^"_MacName_"()"  
     }
     w "HTTP/1.1 200",$c(13,10)
     w "Content-type: "_%request.%data("Content-Type")_"; charset="_%request.%data("CharSet"),$c(13,10)
     w "Connection: close"_$c(13,10,13,10)
     if isMacMethod=1 {
        s cmd=" d "_MacMethod_"^"_MacName_"()" 
     }else{
        s cmd=" d ^"_MacName 
     }
     s $ZTRAP="ErrOnPage2"
     x cmd 
     w *-1,!
     q 1
ErrPre2     
   w "Error: d "_MacPreMethod_"^"_MacName_""
   w !,$ze,!
   w *-1,!
   q 1  
ErrOnPage2
   w cmd
   w !,$ze,!
   w *-1,!
   q 1
}

/// Метод запуска класса
ClassMethod GetClsHtml(ClassName = "", addLib = 1) As %Boolean [ ProcedureBlock = 1 ]
{
    if $l(ClassName)'=0 {
        if $zcvt($e(ClassName,$l(ClassName)-$l("cls"),$l(ClassName)) ,"L")=".cls" {
           s ClassName=$e(ClassName,1,$l(ClassName)-$l(".cls"))          
        }
        if $zObjClassMethod("%CompiledClass","%ExistsId",ClassName)=1 {
             If $System.CLS.IsMthd(ClassName,"OnPreHTTP") {
                d $zObjClassMethod(ClassName,"OnPreHTTP")    
             }
             w "HTTP/1.1 200",$c(13,10)
             w "Content-type: "_%request.%data("Content-Type")_"; charset="_%request.%data("CharSet"),$c(13,10)
             w "Connection: close"_$c(13,10,13,10)
             try{ 
             if addLib=1 {
                if %request.%data("Content-Type")["html" {
                  ;   <script  type='text/javascript' src='/csp/broker/cspxmlhttp.js'></script>
                  ;   <script  type='text/javascript' src='/csp/broker/cspbroker.js'></script>
                  w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>"
                  ; if $zObjClassMethod("%CompiledClass","%ExistsId","%ZSMWrap.RunJob")=1 {
                  ;   w "<script language='JavaScript' type='text/javascript' src='%25ZSMWrap.RunJob.cls'></script>"
                  ; }
               }
             }
             If $System.CLS.IsMthd(ClassName,"OnPage") {
             	d $zObjClassMethod(ClassName,"OnPage")   
             }
             }CATCH err{ zw err }
             q 1
         }
      }   
      q 0
}

/// Закрыть процесс
ClassMethod ClearSession(ProcessID = "test") As %String
{
	s ClientIP=$A(I,1)_"."_$A(I,2)_"."_$A(I,3)_"."_$A(I,4)
    s:ProcessID="" ProcessID="test"
	s LastJobId=@..#GlobalMessage@(ClientIP,ProcessID)=LastJobId    
	w $zu(4,LastJobId)
}

}

