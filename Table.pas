{$mainresource 'table.res'}

uses
  Graphabc, game;

begin
  SetWindowSize(800,500);
  Window.IsFixedSize:=true;
  IsConsoleApplication:=false;
  SetWindowCaption('Table α 0.4 The End Edition by Reolight Miene');
  var Actor:=new player('Reolight',0);
  Actor.Play;
end.