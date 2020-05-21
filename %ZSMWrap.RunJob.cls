/// <script language="JavaScript">
///    var a1=SendServer("User.NewClass1.testCall","test",'222222');
///    alert(a1);
///    var a2=QueryServer("User.NewClass1.NewQuery1","1");
///    alert(a2);
/// </script>
Class %ZSMWrap.RunJob Extends %CSP.Page
{

ClassMethod OnPreHTTP() As %Library.Boolean
{
  if ##this'="%ZSMWrap.RunJob"{ 
     Do %response.SetHeader("Content-Type","text/html")   
     q 1 
  }
  s %request.%data("CharSet")="CP1251"
  ; s %request.%data("CharSet")="UTF-8"
  s %request.%data("Content-Type")="application/javascript"   
  q 1
}

ClassMethod OnPage() As %Status
{

	 if ##this'="%ZSMWrap.RunJob"{	 
	     /*
	     &html<
	       <script language="JavaScript" type="text/javascript" src="%25ZSMWrap.RunJob.cls"></script> 
           <script language="JavaScript" type="text/javascript" src="%25ZSMWrap.RunJob.cls?include=#(##this)#"></script> 
         >
         s ClassName=##this
         If $System.CLS.IsMthd(ClassName,"main"){
          	d $zObjClassMethod(ClassName,"main")   
         }
         */
         w "fffffffffffff"
	     q 1
	 }
	 
 /// Подключение класса и интерпритация его как JS библиотек
  if $d(%request.%data("include")){
	   s ClassCSP=%request.%data("include")
  	   s ClassCSP=$tr(ClassCSP," ","")
       k filtr
	   for ind=1:1:$l(ClassCSP,","){
          // Если класс есть, тогда интерпритируем 
	      if $zObjClassMethod("%CompiledClass","%ExistsId",$p(ClassCSP,",",ind))=1 {
	             d $system.OBJ.GetDependencies($p(ClassCSP,",",ind),.included)
                 s ClassParentTmp=""
                 for {
                    s ClassParentTmp=$o(included(ClassParentTmp))
                    q:ClassParentTmp=""
                    continue:$d(filtr(ClassParentTmp))
                    d ..readJSFunctionFromCacheClass(ClassParentTmp)
                    s filtr(ClassParentTmp)=1
                } 
	     }else{
		    // иначе проверяем есть ли такой пакет, и добавляем весь пакет
		    s ClassTmpPacket=""
		    for {
		         s ClassTmpPacket=$o(^oddDEF(ClassTmpPacket))
		         q:ClassTmpPacket=""  
		         if $e(ClassTmpPacket,1,$l($p(ClassCSP,",",ind)))=$p(ClassCSP,",",ind){
 	                 d $system.OBJ.GetDependencies(ClassTmpPacket,.included)
                     s ClassParentTmp=""
                     for {
                        s ClassParentTmp=$o(included(ClassParentTmp))
                        q:ClassParentTmp=""
                        continue:$d(filtrObj(ClassParentTmp))
                        d ..readJSFunctionFromCacheClass(ClassParentTmp)
                        s filtrObj(ClassParentTmp)=1
                     } 
		         }
		    }  
	     }
	   }
	   q 1   
    }
    
    	
	s ParentClass=""
    if $d(%request.%data("HTTP_REFERER")){
	    s ref = $e(%request.%data("HTTP_REFERER"),$l("http://"_%request.%data("HOST")_"/"),$l(%request.%data("HTTP_REFERER")))    
	    s ParentClass= $SYSTEM.CSP.GetClassName(ref)
    }
    s:ParentClass="" ParentClass=##THIS
	s json=""
	if $d(%request.%data("Content")){
      s json=json_%request.%data("Content")
	}
	if json'=""{
	   #dim %RequestSrv as %ListOfDataTypes
	   do ##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(json,,.%RequestSrv,1)
       if %RequestSrv'="" {
           s ClassMethod=%RequestSrv.Data(1)
           s %method=$p(ClassMethod,".",$l(ClassMethod,"."))
           s %class=$e(ClassMethod,1,$l(ClassMethod)-$l(%method)-1)
           if %class="."{s %class=ParentClass}
		   Set count=%RequestSrv.Count()-1
           set args=count
           s numArg=0
           for j=2:1:%RequestSrv.Count(){
 	          s numArg=numArg+1
              set args(numArg) = %RequestSrv.GetAt(j)
           }
           if $d(%request.%data("function")){
              if %request.%data("function")="QueryServer"{
	             d ##class(%ZSMWrap.RunJob).WriteQuery(ClassMethod,args...)
              }
              if %request.%data("function")="SqlServer"{
	             d ##class(%ZSMWrap.RunJob).WriteSqlJson(ClassMethod,args...)
              }
	          q 1 
           }
           k j,numArg,%RequestSrv,count,ClassMethod
           if '$d(^oddDEF(%class,"m",%method,70)) {
               if '$d(^oddDEF(%class,"m",%method,42)) {
                  do $classmethod(%class, %method, args...)
               } Else {
                  w $classmethod(%class, %method, args...)
               }
           }else{
              if $d(^oddDEF(%class,"m",%method,30)){
                for ind=1:1:^oddDEF(%class,"m",%method,30){
                  w:ind'=1 $c(13,10)
                  d ..ExecFrag(^oddDEF(%class,"m",%method,30,ind),"/*(",")*/")
                }
              }
           }             	       
       }
       q 1
	}
    s %NameSpaceDefault=$zu(5)
    &js< var NameSpace = "#(%NameSpaceDefault)#" >
	d ..readJSFunctionFromCacheClass("%ZSMWrap.RunJob")    
	Quit $$$OK
}

/// <pre>
/// 
/// Варианты параметров классов 
///  1) [ Language = cache, WebMethod ]
///  2) [ Language = javascript, WebMethod ]
/// 
/// Пример классов , которые будут интерпритированы в JS функции:
///     ClassMethod test2()as %String [ Language = cache, WebMethod ]{ zw  q ""}
///     ClientMethod test3() [ Language = javascript, WebMethod ]{    alert('test3()');}
///     Property cspXMLHttp As %String [ ServerOnly = 1 ];
///     Property cspUseGetMethod As %Boolean [ InitialExpression = 0, ServerOnly = 1 ];
///     Property cspMozilla As %Boolean [ InitialExpression = "nill", ServerOnly = 1 ];
///    
/// </pre>
///  <h2>Переписать  %Library.ClassDefinition на  <h2>
ClassMethod readJSFunctionFromCacheClass(ParentClassName = "", MethodName = "", DrawDescript = 1) As %String
{
	
     s onEventFun=",onblur,onerror,onfocus,onload,onresize,onscroll,onbeforeunload,onhashchange,onlanguagechange,onmessage,onoffline,ononline,onpagehide,onpageshow,onpopstate,onrejectionhandled,onstorage,onunhandledrejection,onunload,onabort,oncancel,oncanplay,oncanplaythrough,onchange,onclick,onclose,oncontextmenu,oncuechange,ondblclick,ondrag,ondragend,ondragenter,ondragleave,ondragover,ondragstart,ondrop,ondurationchange,onemptied,onended,oninput,oninvalid,onkeydown,onkeypress,onkeyup,onloadeddata,onloadedmetadata,onloadstart,onmousedown,onmouseenter,onmouseleave,onmousemove,onmouseout,onmouseover,onmouseup,onmousewheel,onpause,onplay,onplaying,onprogress,onratechange,onreset,onseeked,onseeking,onselect,onshow,onstalled,onsubmit,onsuspend,ontimeupdate,ontoggle,onvolumechange,onwaiting,onauxclick,ongotpointercapture,onlostpointercapture,onpointercancel,onpointerdown,onpointerenter,onpointerleave,onpointermove,onpointerout,onpointerover,onpointerup,onbeforecopy,onbeforecut,onbeforepaste,oncopy,oncut,onpaste,onsearch,onselectstart,onwheel,onwebkitfullscreenchange,onwebkitfullscreenerror"
     if $d(%NameSpaceDefault){
	     &js</*  %NameSpaceDefault: #(%NameSpaceDefault)#   */>
     }
     if $zObjClassMethod("%CompiledClass","%ExistsId",ParentClassName)'=1 {
	  &js</*
         Класс #(ParentClassName)# не найден  	  
	  */>
     }
     s ClassOref=##class(%ClassDefinition).%OpenId(ParentClassName)
     if ClassOref {
       s ConstructMethod=$p(ParentClassName,".",$l(ParentClassName,"."))
       s count=ClassOref.Properties.Count() 
       for i=1:1:count {
            s nam=ClassOref.Properties.GetAt(i).Name
            continue:'$d(^oddDEF(ParentClassName,"a",nam,57))
            continue:^oddDEF(ParentClassName,"a",nam,57)'=1
            w "  var "_ClassOref.Properties.GetAt(i).Name_" "
            if $d(^oddDEF(ParentClassName,"a",nam,31)) {
                 s val=^oddDEF(ParentClassName,"a",nam,31)
                 if val="""null""" w "=null;"_$c(13,10)  continue
                 s typ=""
                 if $d(^oddDEF(ParentClassName,"a",nam,5)) {
                    s typ=^oddDEF(ParentClassName,"a",nam,5)
                    if $e(typ,1,1)="%",$l(typ,".")=1 {
                       s typ=$REPLACE(typ,"%","%Library.")
                    }
                 }   
                 if typ="" {
                     if $l(typ ," ")=1 { w "="_$e(val,2,$l(val)-1)_";"_$c(13,10)  continue }
                    try {   x "w "_val   }catch(e){  w "="_$e(val,2,$l(val)-1)_";"_$c(13,10)  continue }
                 }
                 
                 if typ="%Library.Boolean" {
                      if $e(val,1,1)="""" {
                         w "=" 
                         try {   x "w "_val   }catch(e){  if +val=1 { w "=true"  }else     { w "=false" }   }
                      }else {
                        if val=1 { w "=true"  }else     { w "=false" }
                      }
                 }elseif  typ="%Library.Integer" {
                     if $e(val,1,1)="""" {
                         w "=" 
                         try {   x "w "_val   }catch(e){  s val=+val  w val }
                      } else {
                          s val=+val  w val
                      } 
                 }else{
	                 
                     if $e(val,1,1)'="""" {
                           w "=""" 
                           try {   x "w "_val   }catch(e){  w val   }
                           w """"
                      }else {
                         w "="_val
                      } 
                 }
            }
            w ";"_$c(13,10) 
       }
       s ConstructMethodIndex=""
       s count=ClassOref.Methods.Count()
       for i=1:1:count {
            if (MethodName=""){
               continue:$l(ClassOref.Methods.GetAt(i).Name,"OnPage")'=1
               continue:ClassOref.Methods.GetAt(i).Name="OnPreHTTP"
               continue:ClassOref.Methods.GetAt(i).Name="OnPostHTTP"
               continue:ClassOref.Methods.GetAt(i).Name="getLibOne"
               continue:ClassOref.Methods.GetAt(i).Name="GetJSMethodFromClientMethod"
               continue:ClassOref.Methods.GetAt(i).Name="readJSFunctionFromCacheClass"
            }else{
                continue:ClassOref.Methods.GetAt(i).Name'=MethodName   
            }
           /// [ ServerOnly = 1 ]
           // continue:'$d(^oddDEF(ParentClassName,"m",ClassOref.Methods.GetAt(i).Name,59))
           // continue:^oddDEF(ParentClassName,"m",ClassOref.Methods.GetAt(i).Name,59)'=1
           
           /// [ WebMethod ]
           continue:'$d(^oddDEF(ParentClassName,"m",ClassOref.Methods.GetAt(i).Name,51))
           continue:^oddDEF(ParentClassName,"m",ClassOref.Methods.GetAt(i).Name,51)'=1
          
          if $ZCVT(ClassOref.Methods.GetAt(i).Name,"L")=$ZCVT(ConstructMethod,"L"){
             s ConstructMethodIndex=i
             continue    
          }
          
          if DrawDescript=1 {
             if $l(ClassOref.Methods.GetAt(i).Description)>0,ParentClassName'=##this{
                w !,"/*",!
                w $replace(ClassOref.Methods.GetAt(i).Description,"*/","-/-")
                w !,"*/"
             }
          }
          // Получаем JS представление Cache клиент метода
           if ClassOref.Methods.GetAt(i).Language="javascript" {
               w !,"var "_ClassOref.Methods.GetAt(i).Name_"=function("
               s param=ClassOref.Methods.GetAt(i).FormalSpec
               for ind=1:1:$l(param,","){
                   s subParam=$p(param,",",ind)
                   s subParam=$p(subParam,":",1)
                   s subParam=$p(subParam,"=",1)
                   w:ind'=1 ","
                   w subParam
               }
               w "){",!
                 d ..ExecFrag(ClassOref.Methods.GetAt(i).Code,"/*(",")*/")
                 // w ClassOref.Methods.GetAt(i).Code
                 w !,"};"
                
            }
           // Получаем JS представление Cache класс метода
           if ClassOref.Methods.GetAt(i).Language="cache" {
                   w !,"var "_ClassOref.Methods.GetAt(i).Name_"=function(){",!
                   ; if $d(^oddDEF(ParentClassName,"m",ClassOref.Methods.GetAt(i).Name,42)){ w "return "}
                   s WEVENT=$$$cspEncode(%session.Key,$lb(ParentClassName_"."_ClassOref.Methods.GetAt(i).Name))
                   w "   return cspHttpServerMethod('"_WEVENT_"',arguments);"
                   w !,"};"
           }
                
         }
         // После отрисовки функций, создаем конструктор( если конечно он встретился ранее)
         if ConstructMethodIndex'="" {
           s i=ConstructMethodIndex
           if ClassOref.Methods.GetAt(i).Language="javascript" {
              d ..ExecFrag(ClassOref.Methods.GetAt(i).Code,"/*(",")*/")
           }
           if ClassOref.Methods.GetAt(i).Language="cache" {
              s WEVENT=$$$cspEncode(%session.Key,$lb(ParentClassName_"."_ClassOref.Methods.GetAt(i).Name))
              w " cspHttpServerMethod('"_WEVENT_"',arguments);"
           }
         }
       }
       q ""
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

ClientMethod SendServer(MethodName) [ Language = javascript, WebMethod ]
{
	var FunCallBack=null;
    var arr=new Array();
    if ((''+SendServer.arguments[1])=='[object Arguments]'){
       arr.push(SendServer.arguments[0]);     
       for(var ind in SendServer.arguments[1]){
	        if (SendServer.arguments[1][ind]==undefined){continue;} 
	        if (typeof SendServer.arguments[ind] === 'function'){
		       FunCallBack=SendServer.arguments[ind];
	           continue;
	        } 
	        arr.push(SendServer.arguments[1][ind]); 
	   }   
    }else{
       for(var ind in SendServer.arguments){
	     if (SendServer.arguments[ind]==undefined){continue;} 
	     if (typeof SendServer.arguments[ind] === 'function'){
		    FunCallBack=SendServer.arguments[ind];
	        continue;
	     } 
         arr.push(SendServer.arguments[ind]); 
       }   
    }
    var requestSendServer = new XMLHttpRequest();
    if (typeof FunCallBack === 'function'){ 
	   requestSendServer.open('POST', '/*(   w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls"   )*/', true);
       requestSendServer.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
              if (typeof FunCallBack === 'function'){
                    FunCallBack(this.responseText);
              }
           };
       };
       requestSendServer.send(JSON.stringify(arr));  
       return requestSendServer
    }else{
	    requestSendServer.open('POST', '/*(   w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls"  )*/', false);
	    requestSendServer.send(JSON.stringify(arr));  
	    requestSendServer.ontimeout = function (e) { alert('Error:TiomeOut'); }
	    if (requestSendServer.status !== 200) {
	        return {"error":requestSendServer.status}
	    }
	    return requestSendServer.responseText;
    }
}

ClientMethod CallServer(MethodName) [ Language = javascript, WebMethod ]
{
	var FunCallBack=null;
    var arr=new Array();
    if ((''+CallServer.arguments[1])=='[object Arguments]'){
       arr.push(CallServer.arguments[0]);     
       for(var ind in CallServer.arguments[1]){
	        if (CallServer.arguments[1][ind]==undefined){continue;} 
	        if (typeof CallServer.arguments[ind] === 'function'){
		       FunCallBack=CallServer.arguments[ind];
	           continue;
	        } 
	        arr.push(CallServer.arguments[1][ind]); 
	   }   
    }else{
       for(var ind in CallServer.arguments){
	     if (CallServer.arguments[ind]==undefined){continue;} 
	     if (typeof CallServer.arguments[ind] === 'function'){
		    FunCallBack=CallServer.arguments[ind];
	        continue;
	     } 
         arr.push(CallServer.arguments[ind]); 
       }   
    }
    
    var requestSendServer = new XMLHttpRequest();
    requestSendServer.ontimeout = function (e) { alert('Время ожидания ответа вышло!!!!'); }
	if (typeof FunCallBack === 'function'){
       //requestSendServer.open('POST', '%25ZWeb.RunJob.cls', true);
       //requestSendServer.open('POST', '/*(   w $SYSTEM.CSP.GetDefaultApp($ZU(5))_"/"_$zcvt("%ZSMWrap.RunJob","O","URL")_".cls"   )*/', true);
       requestSendServer.open('POST', '/*(   w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls"   )*/', true);
       requestSendServer.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
              if (typeof FunCallBack === 'function'){
                    FunCallBack(this.responseText);
              }
           };
       };
       requestSendServer.send(JSON.stringify(arr));  
       return requestSendServer
    }else{
       // requestSendServer.open('POST', '/*( w $SYSTEM.CSP.GetDefaultApp($ZU(5))_"/"_$zcvt("%ZSMWrap.RunJob","O","URL")_".cls")*/', false);
       requestSendServer.open('POST', '/*( w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls")*/', false);
       requestSendServer.send(JSON.stringify(arr));  
       if (requestSendServer.status !== 200) {
           return {"error":requestSendServer.status}
       }
       return requestSendServer.responseText;
    }
}

ClientMethod ClearSession(MethodName) [ Language = javascript, WebMethod ]
{
	return SendServer("%ZSMWrap.Srv.ClearSession");
}

ClientMethod SqlServer(MethodName) [ Language = javascript, WebMethod ]
{
	var FunCallBack=null;
    var arr=new Array();
    if ((''+SqlServer.arguments[1])=='[object Arguments]'){
       arr.push(SqlServer.arguments[0]);     
       for(var ind in SqlServer.arguments[1]){
	        if (SqlServer.arguments[1][ind]==undefined){continue;} 
	        if (typeof SqlServer.arguments[ind] === 'function'){
		       FunCallBack=SqlServer.arguments[ind];
	           continue;
	        } 
	        arr.push(SqlServer.arguments[1][ind]); 
	   }   
    }else{
       for(var ind in SqlServer.arguments){
	     if (SqlServer.arguments[ind]==undefined){continue;} 
	     if (typeof SqlServer.arguments[ind] === 'function'){
		    FunCallBack=SqlServer.arguments[ind];
	        continue;
	     } 
         arr.push(SqlServer.arguments[ind]); 
       }   
    }
    var requestSendServer = new XMLHttpRequest();
    requestSendServer.ontimeout = function (e) { alert('Время ожидания ответа вышло!!!!'); }
	if (typeof FunCallBack === 'function'){
       requestSendServer.open('POST', '/*(   w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls?function=SqlServer"   )*/', true);
       requestSendServer.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
              if (typeof FunCallBack === 'function'){
                    FunCallBack(JSON.parse(this.responseText));
              }
           };
       };
       requestSendServer.send(JSON.stringify(arr));  
       return requestSendServer
    }else{
       requestSendServer.open('POST', '/*( w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls?function=SqlServer")*/', false);
       requestSendServer.send(JSON.stringify(arr));  
       if (requestSendServer.status !== 200) {
           return {"error":requestSendServer.status}
       }
       return JSON.parse(requestSendServer.responseText);
    }
}

ClientMethod QueryServer(MethodName) [ Language = javascript, WebMethod ]
{
	var FunCallBack=null;
    var arr=new Array();
    if ((''+QueryServer.arguments[1])=='[object Arguments]'){
       arr.push(QueryServer.arguments[0]);     
       for(var ind in QueryServer.arguments[1]){
	        if (QueryServer.arguments[1][ind]==undefined){continue;} 
	        if (typeof QueryServer.arguments[ind] === 'function'){
		       FunCallBack=QueryServer.arguments[ind];
	           continue;
	        } 
	        arr.push(QueryServer.arguments[1][ind]); 
	   }   
    }else{
       for(var ind in QueryServer.arguments){
	     if (QueryServer.arguments[ind]==undefined){continue;} 
	     if (typeof QueryServer.arguments[ind] === 'function'){
		    FunCallBack=QueryServer.arguments[ind];
	        continue;
	     } 
         arr.push(QueryServer.arguments[ind]); 
       }   
    }
    var requestSendServer = new XMLHttpRequest();
    requestSendServer.ontimeout = function (e) { alert('Время ожидания ответа вышло!!!!'); }
	if (typeof FunCallBack === 'function'){
       requestSendServer.open('POST', '/*(   w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls?function=QueryServer"   )*/', true);
       requestSendServer.onreadystatechange = function() {
          if (this.readyState == 4 && this.status == 200) {
              if (typeof FunCallBack === 'function'){
                    FunCallBack(JSON.parse(this.responseText));
              }
           };
       };
       requestSendServer.send(JSON.stringify(arr));  
       return requestSendServer
    }else{
       requestSendServer.open('POST', '/*( w $zcvt("%ZSMWrap.RunJob","O","URL")_".cls?function=QueryServer")*/', false);
       requestSendServer.send(JSON.stringify(arr));  
       if (requestSendServer.status !== 200) {
           return {"error":requestSendServer.status}
       }
       return JSON.parse(requestSendServer.responseText);
    }
}

///  d ##class(%ZSMWrap.RunJob).WriteQuery("User.NewClass1.NewQuery1","1")
ClassMethod WriteQuery(ClassMethod, args...)
{
	s Res=##class(%ResultSet).%New(ClassMethod)
    d Res.Execute(args...)
    s countRaw=0
    w "["
    for {
	    q:'Res.Next() 
        s countRaw=countRaw+1
        w:countRaw>1 ","
        w "{"
	    for ColNum=1:1:Res.GetColumnCount() { 
	        w:ColNum>1 ","
	        s nam = Res.GetColumnName(ColNum)
	        s val = Res.GetData(ColNum)
	        w """"_$zcvt(nam,"O","JS")_""""
	        w ":"
	        s tmp=$tr(val,"1234567890.,")
	        if (($l(tmp)=0) && ($l(val,".")>1)){
	           w ""_$zcvt(val,"O","JS")_""
	        }else{
	           w """"_$zcvt(val,"O","JS")_""""
	        }
 	    }
        w "}"	                
    }
    w "]"
}

ClassMethod WriteSqlJson(SqlStr As %String = "", args...) As %String
{
      if $l(SqlStr)=0 w "[]" q ""
      s SqlStrTmp=$ZCVT(SqlStr,"L")
      q:$l(SqlStrTmp,"insert")>1 "[]"
      q:$l(SqlStrTmp,"update")>1 "[]"
      q:$l(SqlStrTmp,"delete")>1 "[]"
      q:$l(SqlStrTmp,"create ")>1 "[]"
      q:$l(SqlStrTmp,"alter ")>1 "[]"
      q:$l(SqlStrTmp,"drop ")>1 "[]"
      q:$l(SqlStrTmp,"call ")>1 "[]"
      s $ztrap="ztError"
      s SQLobj=##class(%SQL.Statement).%New()
      d SQLobj.%Prepare(SqlStrTmp)
      s DataSet=SQLobj.%Execute(args...)
      s QMeta=DataSet.%GetMetaData()
      s jsonTab = ##class(%Library.ListOfDataTypes).%New()
      s countRaw=0
      w "["
      while DataSet.%Next()
      {
        s countRaw=countRaw+1
        w:countRaw>1 ","
        w:QMeta.columnCount>1 "{"
         for ColNum=1:1:QMeta.columnCount
         {
            w:ColNum>1 ","
            s val=DataSet.%GetData(ColNum)
            s nam=QMeta.columns.GetAt(ColNum).colName
            s typ=QMeta.columns.GetAt(ColNum).ODBCType
            if QMeta.columnCount>1  w """"_$zcvt(nam,"O","JS")_""":"
            if typ=9 { // число
               if val="" w """",""""   continue
               if val=0 w """",""""   continue
               w """"_$zd(+val,4)_"""" continue
            }
            if typ=12 { // текст
                w """"_$zcvt(val,"O","JS")_""""
               continue
            }
          ;  if typ=2 { // сылка на объект
	      ;     w val
	      ;     continue
          ;  }
          ;  if typ=-7 { // Bool
          ;    w val
          ;    continue
          ;  }
            
            if val="" {
                 w """"
                 w """"
            }elseif (+val=val) {
                 w $zcvt(val,"O","JS")
                ; w $zcvt(val,"O","JS")
             }elseif (val="") {
                w "null"
             }else{
                 w """"_$zcvt(val,"O","JS")_""""
                ; w """"_$zcvt(val,"O","JS")_""""
             }
         }  
        w:QMeta.columnCount>1 "}"
      }
     w "]"
     q
ztError   
    w "[]"
    q ""
}

}

