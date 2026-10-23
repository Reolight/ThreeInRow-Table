unit Game;

{$reference System.Threading.dll}
{$reference System.Runtime.InteropServices.dll}
{$reference System.Collections.dll}

uses graphabc,
     System.Threading, 
     System.Runtime.InteropServices, 
     System.Windows.Forms, 
     System.Media, 
     System.Collections,
     System.Collections.Generic;

const
  TileName: array [0..7] of string = ('Dummy','Wood','Stone','Iron ore','Golden ore','Diamond','Iron bar','Golden bar');

var
  Effects: array [1..4] of Picture = (new Picture('image\eff\brocken1.png'),
                                      new Picture('image\eff\brocken2.png'),
                                      new Picture('image\eff\brocken3.png'),
                                      new Picture('image\eff\brocken4.png')
                                      );
  Back: Picture := new Picture('image\back\back.bmp');
  Logf: Text;
  SPlayer1, SPlayer2 : System.Media.SoundPlayer;

type
  tile = class
    //name: string;
    ID: byte;
    DeathMark: boolean;
  constructor Create(id: byte);
  begin
    self.id:=ID;
  end;
end;

type
  item = class (tile)
    Count: integer;
  constructor Create(id: byte; Count: integer);
  begin
    inherited Create(ID);
    self.Count := Count;
  end;
end;

type
  effect = class
    StartFrame: byte;
    EndFrame: byte;
    SecondPerFrame: integer;
    x, y: integer;
    CurrentFrame: integer;
    isLooped: boolean;
    LiveTime: integer;
    isActive: boolean;
  constructor Create(Start, Stop: byte; SecPerFrame: integer; isLooped: boolean);
  begin
    StartFrame:=Start;
    EndFrame:=Stop;
    SecondPerFrame:=SecPerFrame;
    self.isLooped:=isLooped;
    CurrentFrame:=StartFrame;
    LiveTime:=0;
    isActive:=false;
  end;
  
  function toString: string; reintroduce; ///строковое представление эффекта как объекта
  begin
    Result:='StartFrame: '+StartFrame.ToString+' EndFrame: '+EndFrame.ToString+' CurrentFrame: '+CurrentFrame.ToString+' SecondPerFrame: ' + SecondPerFrame.ToString
      + ' Live: ' + LiveTime.ToString + ' IsActive: '+isActive.ToString+' isLooped: '+isLooped.ToString + ' x,y: ' + x.ToString+', '+y.ToString;
  end;
  
  procedure BorN(x,y: integer); ///перерождение, х,у — координаты. Подразумевается тот же эффект
  begin
    isActive:=true;
    self.x:=x; self.y:=y;
    CurrentFrame:=startFrame;
  end;
  
  procedure Draw();  ///отрисовка эффекта в ранее установленных координатах
  begin
    Effects[CurrentFrame].Draw(x-Effects[CurrentFrame].Width div 2, y - Effects[CurrentFrame].Height div 2);
  end;
  
  procedure Refresh(DeltaTime: integer); ///обновление, пересчёт. Нужно знать Δt
  begin
    LiveTime+=DeltaTime;
    while LiveTime >= SecondPerFrame do
    begin
      if SecondPerFrame <= LiveTime then 
      begin
        LiveTime-=SecondPerFrame;
        if CurrentFrame < EndFrame then CurrentFrame += 1
          else if isLooped then CurrentFrame:=StartFrame
          else begin
            self.isActive:=false;
            LiveTime:=0;
            break;
          end;
      end;
    end;
  end;
end;

type
  Table = class
    tiles: array [1..12,1..12] of tile;
    selX: byte;
    selY: byte;
    pict: array [0..255] of picture;
    Δres:array [1..4] of integer;
    lastcombo: integer;
    activefall: boolean;
    EffArray: array of effect;
    EffStack: Stack<effect>;
    EffQueue: Queue<effect>;
  constructor Create;
  begin
    for var i: integer:=1 to 12 do
    begin
      {$omp parallel for}
      for var j:integer:=1 to 12 do
      begin
        var chance:=Random(100)+1;
        if chance<26 then tiles[i,j]:=new tile(1)
        else if chance<51 then tiles[i,j]:=new tile(2)
        else if chance<76 then tiles[i,j]:=new tile(3)
        else tiles[i,j]:=new tile(4);
      end;
    end;
    for var x: integer := 0 to 7 do
      pict[x]:=new picture('image\'+IntToStr(x)+'.png');
    //for var x: integer :=1 to 64 do
    //  EffArray[x]:= new effect(1,4,60,false);
    EffStack:= new Stack<effect>(64);
    for var x:=1 to 64 do
      EffStack.Push(new effect(1,4,60,false));
    EffQueue:= new Queue<effect>(64);
  end;
  
  procedure Render();  ///рендер поля и эффектов
  begin    
    {$omp parallel for private(tiles)}
    for var i:integer := 1 to 12 do
    begin
      {$omp parallel for private(tiles)}
      for var j:integer:=1to 12 do
      begin
        try
          pict[tiles[i,j].ID].Draw(100+(i-1)*32,60+(j-1)*32);
        except
        end;
      end;
    end;
    try
      var ef: effect;
        repeat        
          ef := EffQueue.Peek;
          if not ef.isActive then EffStack.Push(EffQueue.Dequeue);        
        until ef.isActive;
    except end;
    SetLength(EffArray, EffQueue.Count);
    EffQueue.CopyTo(EffArray, 0);
    {$omp parallel for private(EffArray)}    
    for x: integer:=0 to EffQueue.Count-1 do
    begin
      EffArray[x].Draw;
      //TextOut(0,450,x.toString);
    end;
  end;
  
  procedure DieBeautiful(x,y: integer); ///Сдохни красиво! При смерти фишки вызывает эффект
  begin
    //for var i: integer :=1 to 64 do
    //begin
      //if not EffArray[i].isActive then
      //begin
        var ef: effect := EffStack.Pop();
        Ef.BorN(x,y);
        EffQueue.Enqueue(Ef);
        //exit;
      //end;
    //end;
  end;
  
  function Refresh(points: integer): integer;  ///обновление, считаются фишки, которые могут умереть. Счёт идёт двумя циклами, которые, к несчастью,не могут быть распараллелены
  begin
    Δres[1]:=0;Δres[2]:=0;Δres[3]:=0;Δres[4]:=0;      
    var IsSoundPlayerWorks: boolean;
      for x: integer:=1 to 12 do
      begin
        for y: integer:=2 to 11 do
        begin
          if ((tiles[x,y].ID=tiles[x,y+1].ID) and (tiles[x,y-1].ID = tiles[x,y].ID))
            and (tiles[x,y].ID>0)then begin
                if not IsSoundPlayerWorks then
                begin
                  IsSoundPlayerWorks:=true;
                  SPlayer1.SoundLocation:='sound\brocken\glass'+(Random(3)+1).ToString+'.wav';
                  SPlayer1.Play;
                end;
                if not tiles[x,y-1].DeathMark then
                begin
                  Δres[tiles[x,y-1].ID]+=1;
                  points+=tiles[x,y].ID;
                  DieBeautiful(100+(x-1)*32+16,60+(y-2)*32+16);
                end;
                tiles[x,y-1].DeathMark:=true;
                if not tiles[x,y-0].DeathMark then
                begin 
                  Δres[tiles[x,y-0].ID]+=1;
                  points+=tiles[x,y].ID;
                  DieBeautiful(100+(x-1)*32+16,60+(y-1)*32+16);
                end;
                tiles[x,y-0].DeathMark:=true;
                if not tiles[x,y+1].DeathMark then 
                begin 
                  Δres[tiles[x,y+1].ID]+=1; 
                  points+=tiles[x,y].ID; 
                  DieBeautiful(100+(x-1)*32+16,60+(y)*32+16);
                end;
                tiles[x,y+1].DeathMark:=true;
            end;         
        end;
      end;
      
      
      for x: integer:=2 to 11 do
      begin
        for y: integer:=1 to 12 do
        begin          
          if ((tiles[x,y].ID=tiles[x+1,y].ID) and (tiles[x-1,y].ID = tiles[x,y].ID))
            and (tiles[x,y].ID>0)then 
            begin
                if not IsSoundPlayerWorks then
                begin
                  IsSoundPlayerWorks:=true;
                  SPlayer1.SoundLocation:='sound\brocken\glass'+(Random(3)+1).ToString+'.wav';
                  SPlayer1.Play;
                end;
                if not tiles[x-1,y].DeathMark then
                begin 
                  Δres[tiles[x-1,y].ID]+=1; 
                  points+=tiles[x,y].ID;
                  DieBeautiful(100+(x-2)*32+16,60+(y-1)*32+16);
                end;
                tiles[x-1,y].DeathMark:=true;
                if not tiles[x-0,y].DeathMark then 
                begin 
                  Δres[tiles[x-0,y].ID]+=1; 
                  points+=tiles[x,y].ID; 
                  DieBeautiful(100+(x-1)*32+16,60+(y-1)*32+16);
                end;
                tiles[x,y].DeathMark:=true;
                if not tiles[x+1,y].DeathMark then
                begin 
                  Δres[tiles[x+1,y].ID]+=1; 
                  points+=tiles[x,y].ID; 
                  DieBeautiful(100+(x)*32+16,60+(y-1)*32+16);
                end;
                tiles[x+1,y].DeathMark:=true;
            end;         
        end;
      end;
      
      for x: integer:=1 to 12 do
      begin
        for y: integer:=1 to 12 do
        begin          
          if tiles[x,y].DeathMark then begin tiles[x,y].ID:=0; tiles[x,y].DeathMark:=false; end;
        end;
      end;
    activefall:=true;
    result:=points;
  end;
  ///вызывается после смерти хоть одной фишки. Заставляет "поле" падать, генерирую недостающие фишки
  procedure fall; 
  begin
    var c: integer;
    for y: integer :=12 downto 2 do
    begin
      for x: integer := 12 downto 1 do
      begin
        if tiles[x,y].ID=0 then begin tiles[x,y].ID:=tiles[x,y-1].ID; tiles[x,y-1].ID:=0; c+=1; end;
      end;
    end;
    for x: integer := 1 to 12 do
    begin
      if tiles[x,1].ID = 0 then
      begin
        var ran:=Random(100)+1;
        case ran of
          1..25:tiles[x,1].ID :=1;
          26..50:tiles[x,1].ID :=2;
          51..75:tiles[x,1].ID :=3;
          76..100:tiles[x,1].ID :=4;
        end;
      end;
    end;
    if c=0 then activefall:=false else lastcombo:=0;
  end;
end;

type
    BoostButton = class
      x,y,w,h: integer;
      isActive: boolean;
      percentage: double;
      BoostTime: integer;
      NowTime: integer;
      cost: integer;
      BLabel: string;
    constructor Create(x,y,w,h: integer; BoostTime: integer; BLabel: string; cost: integer);
    begin
      self.x:=x;
      self.y:=y;
      self.w:=w;
      self.h:=h;
      self.BoostTime:=BoostTime;
      isActive:=true;
      self.BLabel:=BLabel+' - '+cost.ToString+'p';
      self.cost:=cost;
      percentage:=100;
    end;
    ///отрисовка. Boostable - хватает ли денег/ресурсов на ускорение?
    procedure Draw(Boostable: boolean); 
    begin
      var savesize:=Font.Size;
      SetFontSize(9);
      if isActive then
      begin
        SetBrushColor(clDarkKhaki);
        FillRect(x,y,x+w,y+h);
        if Boostable then SetFontColor(clLime) else SetFontColor(clRed);
        TextOut(x,y,BLabel);
        SetFontColor(clWhite);
        exit;
      end
      else begin
        SetBrushColor(clBlack);
        FillRect(x,y,x+w,y+h);
        SetBrushColor(clGreen);
        FillRect(x,y,x+Round(w*(percentage / 100)), y+h);
        SetBrushStyle(bsClear);
        TextOut(x+w div 2 - w div 4, y+2, Round(percentage).ToString+'% - '+(((BoostTime-NowTime) div 100)/10).ToString+'s');
        SetBrushStyle(bsSolid);
      end;
      SetFontSize(savesize);
    end;
    ///активация. Устанавливает проценты на 0, активность - ложь и текущее время - 0
    procedure Activate;  
    begin
      percentage:=0;
      NowTime:=0;
      isActive:=false;
    end;
    ///Обновление. Если не активно. Добавляет Δt к NowTime, проверяет NowTime<BoostTime, пересчитывает проценты
    procedure Refresh(DeltaTime: integer);  
    begin
      if not isActive then
      begin
        NowTime+=DeltaTime;
        if NowTime<BoostTime then
        begin
          percentage:=NowTime/BoostTime*100;
        end else isActive:=true;
      end;
    end;
    ///находится ли точка с координатами х, у в этом контейнере?
    function Intersect(x, y: integer): boolean;  
    begin
      if (x>=self.x) and (x<=(self.x+w)) and (y>=(self.y)) and (y<=(self.y+h)) then Result:=true
      else Result:=false;
    end;
end;

type
  player = class
    Name: string;
    Money: integer;
    PlayZone: Table;
    GUIpic: Picture;
    SelectedX: byte;
    SelectedY: byte;
    Sel: Picture;
    isGoodCombine: boolean;
    ChX1,ChX2,ChY1,ChY2: byte;
    inventory: array [1..60] of item;
    InvItems: byte;
    Boosts: array [1..2] of BoostButton;
    SaveInvLocation: array [1..7] of byte;
    MaxDeltaTime, MinDeltaTime: integer;
  constructor Create(name: string; money: integer);
  begin
    self.Name:=name;
    self.Money:=Money;
    Playzone:= new Table;
    GUIpic:=new Picture('image\gui.bmp');
    Boosts[1]:=new BoostButton(0,60,99,18,45000,'x2 Res',2500);
    Boosts[2]:=new BoostButton(0,80,99,18,20000,'Notсh',250 );
    for var i: byte :=1 to 60 do
      inventory[i]:=new item(0,0);
    InvItems:=0;    
    Sel:=new Picture('image\active.png');
    isGoodCombine:=true;
    MinDeltaTime:=1000;
  end;
  
  ///добавление предмета ID количеством count в инвентарь 
  procedure AddItem(ID: byte; count: integer); 
  begin
    for var i: integer := 1 to 60 do
    begin
      if inventory[i].ID = ID then
      begin
        if inventory[i].Count+count<1000 then
          begin
            inventory[i].Count += Count;
            exit;
          end else
          begin
            Count-=(999-Inventory[i].Count);
          end;
      end;
    end;
    for var i : integer := 1 to 60 do
    begin
      if inventory[i].ID=0 then
      begin
        inventory[i].ID := ID;
        inventory[i].Count := Count;
        InvItems+=1;
        exit;
      end;
    end;
  end;
  
  procedure TakeItem(ID: byte; count: integer);
  begin
  
  end;
  ///Считает вещи в инвентаре
  function CountItem(ID: byte): integer;
  begin
    var save: integer:=0;
    for i : byte := 1 to 60 do
    begin
      if inventory[i].ID = ID then save+=inventory[i].Count;
    end;
    Result:=save;
  end;
  ///Отрисовывает интерфейс. в том числе кнопки и инвентарь
  procedure gui;  
  begin
    GUIpic.Draw(0,0);
    SetBrushStyle(bsClear);
    SetFontColor(clYellow);
    TextOut(40, 12, IntToStr(Money));
    SetFontColor(clWhite);
    
    begin
      TextOut(145, 12, CountItem(1).ToString);
      TextOut(260, 12, CountItem(2).ToString);
      TextOut(377, 12, CountItem(6).ToString);
      TextOut(493, 12, CountItem(7).ToString);
    end;
    SetBrushStyle(bsSolid);
    SetBrushColor(clBlack);
    FillRect(WindowWidth-200, 60, WindowWidth, 60+InvItems*22);
    var savesize:integer:=Font.Size;
    SetFontSize(12);
    var ICount: byte := 0;
    for i : integer := 1 to 60 do
    begin
      if  inventory[i].ID>0 then
      begin
        TextOut(WindowWidth - 195, 62 + ICount * 22, TileName[inventory[i].ID]+': '+inventory[i].Count.ToString);
        ICount+=1;
      end;
    end;
    SetFontSize(savesize);
    for i : integer := 1 to 2 do //to length of boost
      Boosts[i].Draw(Money-Boosts[i].cost >= 0);
  end;
  ///проверка на хорошую комбинацию. Не может быть распараллелена.
  procedure Check(x,y: integer); 
  begin
    for i: byte:=x-1 to x+2 do
    begin
      for j:byte:=y-1 to y+2 do
      begin
        try
          if (PlayZone.tiles[i,j].ID=PlayZone.tiles[i-1,j].ID) and (PlayZone.tiles[i+1,j].ID=PlayZone.tiles[i,j].ID)
            then begin isGoodCombine:=true; exit; end;
          if (PlayZone.tiles[i,j].ID=PlayZone.tiles[i,j-1].ID) and (PlayZone.tiles[i,j].ID=PlayZone.tiles[i,j+1].ID)
            then begin isGoodCombine:=true; exit; end;
        except
        
        end;
      end;
    end;
    isGoodCombine:=false;
  end;
  ///мышь,обработка. Возможны параллельность в некоторых случаях
  procedure Mouse(x,y,mb:integer); 
  begin
    var NewX: byte :=(x-100) div 32 + 1;
    var NewY: byte :=(y-60) div 32 + 1;
    
    for i : byte := 1 to 2 do //to length of boosts do
    begin
      if (Boosts[i].Intersect(x,y)) and (mb = 1) and (Money>=Boosts[i].cost) then
      begin
        Money-=Boosts[i].cost;
        Boosts[i].Activate;
        break;
      end;
    end;
    
    if (((SelectedX=0) and (SelectedY=0)) or ((Abs(SelectedX-NewX)>0) and (Abs(SelectedY-NewY)>0))
        or ((Abs(SelectedX-NewX)=0)and(Abs(SelectedY-NewY)>1))or((Abs(SelectedY-NewY)=0)and(Abs(SelectedX-NewX)>1))) and
              ((NewX in [1..12]) and (NewY in [1..12])) then
           begin
             SelectedX:=NewX;
             SelectedY:=NewY;
             exit;
           end else if not ((NewX in [1..12]) and (NewY in [1..12])) then
           begin
             SelectedX:=0;
             SelectedY:=0;
           end;
             
      
    if ((SelectedX > 0) and (selectedY > 0)) then
    begin
      if (NewX>0) and (NewY>0) then
      begin
        if (SelectedY=(y-60) div 32 + 1) then
        begin
          if (SelectedX-((x-100) div 32 + 1)=1) then
          begin
            var id: byte:=PlayZone.tiles[SelectedX,SelectedY].ID;
            PlayZone.tiles[SelectedX,SelectedY].ID:=PlayZone.tiles[SelectedX-1,SelectedY].ID;
            PlayZone.tiles[SelectedX-1,SelectedY].ID:=ID;
            Check(SelectedX,SelectedY);
            ChX1:=SelectedX;
            ChY1:=SelectedY;
            ChX2:=(x-100) div 32 + 1;
            ChY2:=(y-60) div 32 + 1;
            SelectedX:=0;
            SelectedY:=0;
            PlayZone.lastcombo:=0;
            exit;
          end
          else if (SelectedX-((x-100) div 32 + 1)=-1) then
          begin
            var id: byte:=PlayZone.tiles[SelectedX,SelectedY].ID;
            PlayZone.tiles[SelectedX,SelectedY].ID:=PlayZone.tiles[SelectedX+1,SelectedY].ID;
            PlayZone.tiles[SelectedX+1,SelectedY].ID:=ID;
            Check(SelectedX,SelectedY);
            ChX1:=SelectedX;
            ChY1:=SelectedY;
            ChX2:=(x-100) div 32 + 1;
            ChY2:=(y-60) div 32 + 1;
            SelectedX:=0;
            SelectedY:=0;
            PlayZone.lastcombo:=0;
            exit;
          end;
        end else if SelectedX = (x-100) div 32 + 1 then
        begin
          if (SelectedY-((Y-60) div 32 + 1)=1) then
          begin
            var id: byte:=PlayZone.tiles[SelectedX,SelectedY].ID;
            PlayZone.tiles[SelectedX,SelectedY].ID:=PlayZone.tiles[SelectedX,SelectedY-1].ID;
            PlayZone.tiles[SelectedX,SelectedY-1].ID:=ID;
            Check(SelectedX,SelectedY);
            ChX1:=SelectedX;
            ChY1:=SelectedY;
            ChX2:=(x-100) div 32 + 1;
            ChY2:=(y-60) div 32 + 1;
            SelectedX:=0;
            SelectedY:=0;
            PlayZone.lastcombo:=0;
            exit;
          end
          else if (SelectedY-((Y-60)div 32 + 1)=-1) then
          begin
            var id: byte:=PlayZone.tiles[SelectedX,SelectedY].ID;
            PlayZone.tiles[SelectedX,SelectedY].ID:=PlayZone.tiles[SelectedX,SelectedY+1].ID;
            PlayZone.tiles[SelectedX,SelectedY+1].ID:=ID;
            Check(SelectedX,SelectedY);
            ChX1:=SelectedX;
            ChY1:=SelectedY;
            ChX2:=(x-100) div 32 + 1;
            ChY2:=(y-60) div 32 + 1;
            SelectedX:=0;
            SelectedY:=0;
            PlayZone.lastcombo:=0;
            exit;
          end;
        end;
       //if ((SelectedX -(x-100) div 32 + 1 in [-1..1])
       //   or(SelectedY-(y-60) div 32 + 1 in [-1..1]))
       // then begin
        //  SelectedX:=(x-100) div 32 + 1;
        //  SelectedY:=(y-60) div 32 + 1;
       // end;
      end else      
      begin
        SelectedX:=0;
        SelectedY:=0;
      end;
    end;
  end;
  ///экстренное завершение
  procedure Closed; 
  begin
    Writeln(Logf,'------------------------------------>ExtraShutdown<-------------------------------------------');
    Writeln(Logf,'Effects info');
    
    Writeln(Logf,'Min: '+MinDeltaTime.ToString+' Max: '+MinDeltaTime.ToString);
    for a: integer := 0 to PlayZone.EffArray.Length-1 do
      Writeln(Logf,PlayZone.EffArray[a].ToString);
    Close(Logf)
  end;
  
  procedure Play; ///игровой цикл
  begin
    var delMil:=Milliseconds;
    LockDrawing;
    Assign(Logf,'log.txt');
    Rewrite(Logf);
    SPlayer1:=new SoundPlayer;
    repeat
      Back.Draw;
      delMil:=MillisecondsDelta;
      PlayZone.lastcombo+=delMil;
      {$omp parallel sections}
      begin
        PlayZone.Render;      
        GUI;
      end;
      
      begin
        TextOut(0,450,delMil.ToString);
        if SelectedX>0 then Sel.Draw(100+(SelectedX-1)*32,60+(SelectedY-1)*32,32,32);
        redraw;
        if delMil<MinDeltaTime then MinDeltaTime:=DelMil;
        if delMil>MaxDeltaTime then MaxDeltaTime:=delMil;
      end;
      
      if not PlayZone.activefall then begin Money:=PlayZone.Refresh(Money); end;
      {$omp parallel for private(delMil)}
      for var i: integer :=1 to 2 do //to length of boosts do
        if not Boosts[i].isActive then Boosts[i].Refresh(delMil);
      
      for var i: integer :=1 to 4 do
      begin
        if not Boosts[1].isActive then AddItem(i, PlayZone.Δres[i]*2) //boost effect, lalka
          else AddItem(i, PlayZone.Δres[i]);
        PlayZone.Δres[i]:=0;
      end;
      if (PlayZone.lastcombo>120) and (PlayZone.activefall) then begin PlayZone.Fall;  end;
      
      if (PlayZone.lastcombo>120) and (PlayZone.activefall = false) and (isGoodCombine = false) then
      begin
        var save: byte:=PlayZone.tiles[ChX1,ChY1].ID;
        PlayZone.tiles[ChX1,ChY1].ID:=PlayZone.tiles[ChX2,ChY2].ID;
        PlayZone.tiles[ChX2,ChY2].ID:=save;
        isGoodCombine:=true;
      end;
      
      try
      {$omp parallel for}
      for x: integer:=0 to PlayZone.EffQueue.Count-1 do
        PlayZone.EffArray[x].Refresh(delMil);
      except end;
      
      OnClose:=Closed;
      if (PlayZone.activefall=false) and (isGoodCombine) then OnMouseDown:=Mouse;
    until false;
  end;
end;
end.
