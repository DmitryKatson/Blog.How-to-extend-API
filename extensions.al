tableextension 50100 "GenJnlLineExt" extends "Gen. Journal Line"
{
    fields
    {
        field(50100; "myDecimalField"; Decimal) { }
        field(50101; "myTextField"; Text[50]) { }
        field(50102; "myBooleanField"; Boolean) { }
    }

    trigger OnAfterInsert()
    begin
        ParseJsonFromAPI();
    end;

    local procedure ParseJsonFromAPI()
    var
        Jtoken: JSonToken;
        Jobj: JsonObject;
    begin
        if Session.CurrentClientType <> ClientType::ODataV4 then
            exit;

        if Rec.Comment = '' then
            exit;

        if not Jtoken.ReadFrom(Rec.Comment) then
            exit;

        Jobj := Jtoken.AsObject;

        Rec.myBooleanField := GetJsonValueAsBoolean(Jobj, 'myBooleanField');
        Rec.myDecimalField := GetJsonValueAsDecimal(Jobj, 'myDecimalField');
        Rec.myTextField := GetJsonValueAsText(Jobj, 'myTextField');
        Rec.Comment := '';
        Rec.Modify();
    end;

    local procedure GetJsonValueAsText(var JObj: JsonObject; Property: text) Value: Text;
    var
        JValue: JsonValue;
        JToken: JsonToken;
    begin
        JObj.Get(Property, JToken);
        Value := JToken.AsValue.AsText();
    end;

    local procedure GetJsonValueAsDecimal(var JObj: JsonObject; Property: text) Value: Decimal;
    var
        JValue: JsonValue;
        JToken: JsonToken;
    begin
        JObj.Get(Property, JToken);
        Value := JToken.AsValue.AsDecimal();
    end;

    local procedure GetJsonValueAsBoolean(var JObj: JsonObject; Property: text) Value: Boolean;
    var
        JValue: JsonValue;
        JToken: JsonToken;
    begin
        JObj.Get(Property, JToken);
        Value := JToken.AsValue.AsBoolean();
    end;
}

pageextension 50100 GenJnlLinesExt extends "General Journal"
{
    layout
    {
        addlast(Control1)
        {
            field(myBooleanField; Rec.myBooleanField) { ApplicationArea = All; }
            field(myDecimalField; Rec.myDecimalField) { ApplicationArea = All; }
            field(myTextField; Rec.myTextField) { ApplicationArea = All; }
        }
    }
}

