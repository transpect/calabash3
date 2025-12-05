# This is a fairly naive Powershell script that constructs a classpath for
# running XML Calabash. The idea is that it puts jar files from the "extra"
# directory ahead of jar files from the "lib" directory. This should support
# overriding jars. And supports running steps that require extra libraries.

# 1. Construct the classpath

$cp = Join-Path -Path $PSScriptRoot -ChildPath "xmlcalabash-app-3.0.30.jar"

if (![System.IO.File]::Exists("$cp")) {
  Write-Host "XML Calabash script did not find the 3.0.30 distribution jar"
  Exit 1
}

$cpdelim = if($IsLinux -or $IsMacOS) {":"} else {";"}
$slash = if($IsLinux -or $IsMacOS) {"/"} else {"\"}

$extraRoot = Join-Path -Path $PSScriptRoot -ChildPath "extra"
Get-ChildItem $extraRoot -Filter *.jar |
ForEach-Object {
  $cp = "${cp}${cpdelim}$($_.FullName)"
}

$libRoot = Join-Path -Path $PSScriptRoot -ChildPath "lib"
Get-ChildItem $libRoot -Filter *.jar |
ForEach-Object {
  $cp = "${cp}${cpdelim}$($_.FullName)"
}

# 2. Find arguments that begin -D and assume they're Java properties. (Users
#    will have to quote them if they contain spaces or colons, see item 3.)

$Encoding = ""
$Param = ""
$JavaProp = foreach ($Item in $args)
{
   if ($Item.StartsWith("-D"))
   {
      if ($Item.StartsWith("-Dfile.encoding="))
      {
         $Encoding = $Item
      }
      $Item
   }
}

# The default charset changed in Java 18. In Java 18 and later, it's always
# UTF-8. Except, it ain't on Windows, mate. You can fix this by passing an
# explicit -D"file.encoding=some-encoding" property. But if you *don't* do that,
# this script adds -D"file.encoding=COMPAT" to get backwards-compatible
# behavior.
# See https://medium.com/@andbin/jdk-18-and-the-utf-8-as-default-charset-8451df737f90

if ($Encoding -eq "") {
   $JavaProp += ("-Dfile.encoding=COMPAT")
}

# 3. Fix the argument parsing. The way arguments are parsed by PowerShell when
#    passed to another program breaks strings at ":". That's inconvenient, so
#    try to fix it. FYI: https://github.com/PowerShell/PowerShell/issues/23819
#    Also disregard any argument that begins -D because that's a Java property
#    setting.

$Param = ""
$NewArgs = foreach ($Item in $args)
{
   If ($Item.EndsWith(':'))
   {
      $Param = $Item
      continue
   }

   if ($Item.StartsWith("-D"))
   {
        continue
   }

   if ($Param -ne "")
   {
     $Param + $Item
     $Param = ""
   }
   else
   {
      $Item
   }
}

# 4. Sort out where the java executable lives; assume it's either in
#    $env:JAVA_HOME\bin\java.exe or is on the classpath.

$java = "java"
if ($env:JAVA_HOME -ne "")
{
   $java = Join-Path -Path $env:JAVA_HOME -ChildPath "bin\java.exe"
}

# 4. Run XML Calabash

& $java $JavaProp -cp "$cp" com.xmlcalabash.app.Main $NewArgs
