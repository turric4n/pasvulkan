unit UnitProject;
{$i ..\..\PasVulkan.inc}
{$ifndef fpc}
 {$ifdef conditionalexpressions}
  {$if CompilerVersion>=24.0}
   {$legacyifend on}
  {$ifend}
 {$endif}
{$endif}

interface

uses SysUtils,Classes,UnitVersion,UnitGlobals;

procedure CreateProject;
procedure UpdateProject;
procedure BuildProject;
procedure RunProject;

implementation

function GetRelativeFileList(const aPath:UnicodeString;const aMask:UnicodeString={$ifdef Unix}'*'{$else}'*.*'{$endif};const aParentPath:UnicodeString=''):TStringList;
var SearchRec:{$if declared(TUnicodeSearchRec)}TUnicodeSearchRec{$else}TSearchRec{$ifend};
    SubList:TStringList;
begin
 result:=TStringList.Create;
 try
  if FindFirst(IncludeTrailingPathDelimiter(aPath)+aMask,faAnyFile,SearchRec)=0 then begin
   try
    repeat
     if (SearchRec.Name<>'.') and (SearchRec.Name<>'..') then begin
      if (SearchRec.Attr and faDirectory)<>0 then begin
       result.Add(String(ExcludeLeadingPathDelimiter(IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(aParentPath)+SearchRec.Name))));
       SubList:=GetRelativeFileList(IncludeTrailingPathDelimiter(aPath)+SearchRec.Name,
                                    aMask,
                                    IncludeTrailingPathDelimiter(aParentPath)+SearchRec.Name);
       if assigned(SubList) then begin
        try
         result.AddStrings(SubList);
        finally
         FreeAndNil(SubList);
        end;
       end;
      end else begin
       result.Add(String(ExcludeLeadingPathDelimiter(IncludeTrailingPathDelimiter(aParentPath)+SearchRec.Name)));
      end;
     end;
    until FindNext(SearchRec)<>0;
   finally
    FindClose(SearchRec);
   end;
  end;
 except
  FreeAndNil(result);
  raise;
 end;
end;

procedure CopyFile(const aSourceFileName,aDestinationFileName:UnicodeString);
var SourceFileStream,DestinationFileStream:TFileStream;
begin
 SourceFileStream:=TFileStream.Create(String(aSourceFileName),fmOpenRead or fmShareDenyWrite);
 try
  DestinationFileStream:=TFileStream.Create(String(aDestinationFileName),fmCreate);
  try
   if DestinationFileStream.CopyFrom(SourceFileStream,SourceFileStream.Size)<>SourceFileStream.Size then begin
    raise EInOutError.Create('InOutError at copying "'+String(aSourceFileName)+'" to "'+String(aDestinationFileName)+'"');
   end;
  finally
   FreeAndNil(DestinationFileStream);
  end;
 finally
  FreeAndNil(SourceFileStream);
 end;
end;

procedure CopyAndSubstituteTextFile(const aSourceFileName,aDestinationFileName:UnicodeString;const aSubstitutions:array of UnicodeString);
var Index,SubstitutionIndex,CountSubstitutions:Int32;
    StringList:TStringList;
    Line:String;
begin
 CountSubstitutions:=length(aSubstitutions);
 if CountSubstitutions>0 then begin
  StringList:=TStringList.Create;
  try
   StringList.LoadFromFile(String(aSourceFileName));
   for Index:=0 to StringList.Count-1 do begin
    Line:=StringList[Index];
    SubstitutionIndex:=0;
    while (SubstitutionIndex+1)<CountSubstitutions do begin
     Line:=(StringReplace(Line,String(aSubstitutions[SubstitutionIndex]),String(aSubstitutions[SubstitutionIndex+1]),[rfReplaceAll,rfIgnoreCase]));
     inc(SubstitutionIndex,2);
    end;
    StringList[Index]:=Line;
   end;
   StringList.SaveToFile(String(aDestinationFileName));
  finally
   FreeAndNil(StringList);
  end;
 end else begin
  CopyFile(aSourceFileName,aDestinationFileName);
 end;
end;

procedure CreateProject;
var Index:Int32;
    ProjectTemplateFileList,StringList:TStringList;
    ProjectPath,ProjectMetaDataPath,
    ProjectUUIDFileName,
    FileName,SourceFileName,DestinationFileName:UnicodeString;
    ProjectUUID:String;
    GUID:TGUID;
begin

 if not DirectoryExists(PasVulkanProjectTemplatePath) then begin
  WriteLn(ErrOutput,'Fatal: "',PasVulkanProjectTemplatePath,'" doesn''t exist!');
  exit;
 end;

 if length(CurrentProjectName)=0 then begin
  WriteLn(ErrOutput,'Fatal: No valid project name!');
  exit;
 end;

 ProjectPath:=IncludeTrailingPathDelimiter(PasVulkanProjectsPath+CurrentProjectName);
 if DirectoryExists(ProjectPath) then begin
  WriteLn(ErrOutput,'Fatal: "',ProjectPath,'" already exists!');
  exit;
 end;

 WriteLn('Creating "',ProjectPath,'" ...');
 if not ForceDirectories(ProjectPath) then begin
  WriteLn(ErrOutput,'Fatal: "',ProjectPath,'" couldn''t created!');
 end;

 ProjectMetaDataPath:=IncludeTrailingPathDelimiter(ProjectPath+'metadata');
 WriteLn('Creating "',ProjectMetaDataPath,'" ...');
 if not ForceDirectories(ProjectMetaDataPath) then begin
  WriteLn(ErrOutput,'Fatal: "',ProjectMetaDataPath,'" couldn''t created!');
  exit;
 end;

 CreateGUID(GUID);
 ProjectUUID:=LowerCase(GUIDToString(GUID));

 ProjectUUIDFileName:=ProjectMetaDataPath+'uuid';

 WriteLn('Creating "',ProjectUUIDFileName,'" ...');
 StringList:=TStringList.Create;
 try
  StringList.Text:=ProjectUUID;
  StringList.SaveToFile(String(ProjectUUIDFileName));
 finally
  FreeAndNil(StringList);
 end;

 ProjectTemplateFileList:=GetRelativeFileList(PasVulkanProjectTemplatePath);
 if assigned(ProjectTemplateFileList) then begin
  try
   for Index:=0 to ProjectTemplateFileList.Count-1 do begin
    FileName:=UnicodeString(ProjectTemplateFileList.Strings[Index]);
    SourceFileName:=PasVulkanProjectTemplatePath+FileName;
    DestinationFileName:=ProjectPath+FileName;
    if length(DestinationFileName)>0 then begin
     if (DestinationFileName[length(DestinationFileName)]=DirectorySeparator) or
        (IncludeTrailingPathDelimiter(ExtractFilePath(DestinationFileName))=DestinationFileName) then begin
      WriteLn('Creating "',DestinationFileName,'" ...');
      if not ForceDirectories(DestinationFileName) then begin
       WriteLn(ErrOutput,'Fatal: "',DestinationFileName,'" couldn''t created!');
       break;
      end;
     end else begin
      DestinationFileName:=UnicodeString(StringReplace(String(DestinationFileName),'projecttemplate',String(CurrentProjectName),[rfReplaceAll,rfIgnoreCase]));
      WriteLn('Copying "',SourceFileName,'" to "',DestinationFileName,'" ...');
      if FileName='src'+DirectorySeparator+'projecttemplate.dpr' then begin
       CopyAndSubstituteTextFile(SourceFileName,
                                 DestinationFileName,
                                 ['projecttemplate',CurrentProjectName]);
      end else if FileName='src'+DirectorySeparator+'projecttemplate.dproj' then begin
       CopyAndSubstituteTextFile(SourceFileName,
                                 DestinationFileName,
                                 ['projecttemplate',CurrentProjectName,
                                  '{00000000-0000-0000-0000-000000000000}',UnicodeString(ProjectUUID)]);
      end else if FileName='src'+DirectorySeparator+'projecttemplate.lpi' then begin
       CopyAndSubstituteTextFile(SourceFileName,
                                 DestinationFileName,
                                 ['projecttemplate',CurrentProjectName]);
      end else if ExtractFileExt(FileName)='.pas' then begin
       CopyAndSubstituteTextFile(SourceFileName,
                                 DestinationFileName,
                                 ['projecttemplate',CurrentProjectName]);
      end else begin
       CopyFile(SourceFileName,DestinationFileName);
      end;
     end;
    end;
   end;
  finally
   FreeAndNil(ProjectTemplateFileList);
  end;
 end;

end;

procedure UpdateProject;
begin
end;

procedure BuildProject;
begin
end;

procedure RunProject;
begin
end;

end.

