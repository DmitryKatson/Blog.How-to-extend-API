page 50100 "CustomJournalLinesEntity"
{
    PageType = API;
    Caption = 'customJournalLines';
    APIPublisher = 'DmitryKatson';
    APIGroup = 'customAPI';
    APIVersion = 'v1.0';
    EntityName = 'customJournalLine';
    EntitySetName = 'customJournalLines';
    SourceTable = "Gen. Journal Line";
    DelayedInsert = true;
    ODataKeyFields = SystemId;

    layout
    {
        area(Content)
        {
            repeater(General)
            {
                field(Id; Rec.SystemId)
                {
                    Editable = false;
                    ApplicationArea = Basic;

                }
                field(extraInfo; ExtraInfoJSON)
                {
                    ApplicationArea = Basic;
                }
                field(journalDisplayName; GlobalJournalDisplayNameTxt)
                {
                    ToolTip = 'Specifies the Journal Batch Name of the Journal Line';
                    ApplicationArea = Basic;

                    trigger OnValidate()
                    begin
                        ERROR(CannotEditBatchNameErr);
                    end;

                }
                field(lineNumber; Rec."Line No.")
                {
                    ApplicationArea = Basic;

                }
                field(accountId; Rec."Account Id")
                {
                    ApplicationArea = Basic;

                    trigger OnValidate()
                    begin
                        DoValidateGLAccountId(Rec."Account Id");
                    end;

                }
                field(accountNumber; AccountNo)
                {
                    ApplicationArea = Basic;
                    trigger OnValidate()
                    begin
                        TryToGetAccountNoFromICPartnerAccount(AccountNo);
                        Rec.Validate("Account No.", AccountNo);
                        DoValidateGLAccount(Rec."Account No.");
                    end;
                }
                field(postingDate; Rec."Posting Date")
                {
                    ApplicationArea = Basic;

                }
                field(documentNumber; Rec."Document No.")
                {
                    ApplicationArea = Basic;

                }
                field(externalDocumentNumber; Rec."External Document No.")
                {
                    ApplicationArea = Basic;

                }
                field(amount; Rec.Amount)
                {
                    ApplicationArea = Basic;

                }
                field(description; Rec.Description)
                {
                    ApplicationArea = Basic;

                }
                field(comment; Rec.Comment)
                {
                    ApplicationArea = Basic;
                }
                field(lastModifiedDateTime; Rec."Last Modified DateTime")
                {
                    ApplicationArea = Basic;

                }
            }
        }
    }

    var
        ExtraInfoJSON: Text;
        GLAccount: Record "G/L Account";
        GraphMgtJournalLines: Codeunit "Graph Mgt - Journal Lines";
        LibraryAPIGeneralJournal: Codeunit "Library API - General Journal";
        DimensionsJSON: Text;
        PreviousDimensionsJSON: Text;
        GlobalJournalDisplayNameTxt: code[10];
        FiltersChecked: Boolean;
        DimensionsSet: Boolean;
        BlankGUID: Guid;
        AccountNo: code[20];
        FiltersNotSpecifiedErr: Label 'You must specify a journal batch ID or a journal ID to get a journal line.';
        CannotEditBatchNameErr: Label 'The Journal Batch Display Name is not editable.';
        AccountValuesDontMatchErr: Label 'The account values do not match to a specific Account.';
        AccountIdDoesNotMatchAnAccountErr: Label 'The "accountId" does not match to an Account.';
        AccountNumberDoesNotMatchAnAccountErr: Label 'The "accountNumber" does not match to an Account.';
        ICAccountMappingForAccountNotFoundErr: Label 'The mapping for %1 is not found.';

    trigger OnOpenPage()
    begin
        GraphMgtJournalLines.SetJournalLineFilters(Rec);
    end;

    trigger OnAfterGetRecord()
    begin
        SetCalculatedFields;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        CheckFilters;

        ClearCalculatedFields;

        Rec."Document Type" := Rec."Document Type"::" ";
        Rec."Account Type" := Rec."Account Type"::"G/L Account";
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        TempGenJournalLine: Record "Gen. Journal Line" temporary;
    begin
        TempGenJournalLine.RESET;
        TempGenJournalLine.COPY(Rec);

        CLEAR(Rec);
        GraphMgtJournalLines.SetJournalLineTemplateAndBatch(
          Rec, LibraryAPIGeneralJournal.GetBatchNameFromId(TempGenJournalLine.GETFILTER("Journal Batch Id")));
        LibraryAPIGeneralJournal.InitializeLine(
          Rec, TempGenJournalLine."Line No.", TempGenJournalLine."Document No.", TempGenJournalLine."External Document No.");

        GraphMgtJournalLines.SetJournalLineValues(Rec, TempGenJournalLine);

        UpdateDimensions(FALSE);
        SetCalculatedFields;
        ParseExtraInformation();
    end;

    local procedure ParseExtraInformation();
    begin
        if ExtraInfoJSON = '' then
            exit;

        OnBeforeParseExtraInformation(ExtraInfoJSON, Rec);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeParseExtraInformation(ExtraInfoJSON: Text; var Rec: Record "Gen. Journal Line")
    begin
    end;


    trigger OnModifyRecord(): Boolean
    var
        GenJournalLine: Record "Gen. Journal Line";
    begin
        GenJournalLine.SETRANGE(SystemId, Rec.SystemId);
        GenJournalLine.FINDFIRST;

        IF Rec."Line No." = GenJournalLine."Line No." THEN
            Rec.MODIFY(TRUE)
        ELSE BEGIN
            GenJournalLine.TRANSFERFIELDS(Rec, FALSE);
            GenJournalLine.RENAME(Rec."Journal Template Name", Rec."Journal Batch Name", Rec."Line No.");
            Rec.TRANSFERFIELDS(GenJournalLine, TRUE);
        END;

        UpdateDimensions(TRUE);
        SetCalculatedFields;
        ParseExtraInformation();

        EXIT(FALSE);
    end;

    trigger OnAfterGetCurrRecord()
    begin
        IF NOT FiltersChecked THEN BEGIN
            CheckFilters;
            FiltersChecked := TRUE;
        END;
    end;

    local procedure SetCalculatedFields()
    var
        GraphMgtComplexTypes: Codeunit "Graph Mgt - Complex Types";
    begin
        GlobalJournalDisplayNameTxt := Rec."Journal Batch Name";
        DimensionsJSON := GraphMgtComplexTypes.GetDimensionsJSON(Rec."Dimension Set ID");
        PreviousDimensionsJSON := DimensionsJSON;
    end;

    local procedure ClearCalculatedFields()
    begin
        CLEAR(GlobalJournalDisplayNameTxt);
        CLEAR(DimensionsJSON);
        CLEAR(PreviousDimensionsJSON);
        CLEAR(DimensionsSet);
    end;

    LOCAL procedure CheckFilters()
    begin
        IF (Rec.GETFILTER("Journal Batch Id") = '') AND
           (Rec.GETFILTER(SystemId) = '')
        THEN
            ERROR(FiltersNotSpecifiedErr);

    end;

    LOCAL procedure UpdateDimensions(LineExists: Boolean)
    var
        GraphMgtComplexTypes: Codeunit "Graph Mgt - Complex Types";
        DimensionManagement: Codeunit DimensionManagement;
        NewDimensionSetId: Integer;
    begin
        IF NOT DimensionsSet THEN
            EXIT;
        TryToGetDimensionsFromICPartnerDimensions(DimensionsJSON);
        GraphMgtComplexTypes.GetDimensionSetFromJSON(DimensionsJSON, Rec."Dimension Set ID", NewDimensionSetId);
        IF Rec."Dimension Set ID" <> NewDimensionSetId THEN BEGIN
            Rec."Dimension Set ID" := NewDimensionSetId;
            DimensionManagement.UpdateGlobalDimFromDimSetID(NewDimensionSetId, Rec."Shortcut Dimension 1 Code", Rec."Shortcut Dimension 2 Code");
            IF LineExists THEN
                Rec.MODIFY;
        END;
    end;

    local procedure DoValidateGLAccountId(AccountId: Guid)
    begin
        IF AccountId = BlankGUID THEN BEGIN
            Rec."Account No." := '';
            EXIT;
        END;

        GLAccount.SETRANGE(SystemId, AccountId);
        IF NOT GLAccount.FINDFIRST THEN
            ERROR(AccountIdDoesNotMatchAnAccountErr);

        Rec."Account No." := GLAccount."No.";
    end;


    local procedure DoValidateGLAccount(GLAccountNo: code[20])
    begin
        IF GLAccount."No." <> '' THEN BEGIN
            IF GLAccount."No." <> GLAccountNo THEN
                ERROR(AccountValuesDontMatchErr);
            EXIT;
        END;

        IF GLAccountNo = '' THEN BEGIN
            Rec."Account Id" := BlankGUID;
            EXIT;
        END;

        IF NOT GLAccount.GET(GLAccountNo) THEN
            ERROR(AccountNumberDoesNotMatchAnAccountErr);

        Rec."Account Id" := GLAccount.SystemId;
    end;

    local procedure TryToGetAccountNoFromICPartnerAccount(var GLAccountNo: code[20])
    var
        MappedAccountNo: Code[20];
    begin
        MappedAccountNo := GetGLAccountFromICGLAccount(GLAccountNo);
        if MappedAccountNo = '' then
            exit;
        GLAccountNo := MappedAccountNo;
    end;


    local procedure GetGLAccountFromICGLAccount(ICAccountNo: Code[20]): Code[20]
    var
        ICGLAccount: Record "IC G/L Account";
    begin
        IF Not ICGLAccount.GET(ICAccountNo) THEN
            //Error(StrSubstNo(ICAccountMappingForAccountNotFoundErr, ICAccountNo));
            exit('');
        ICGLAccount.TESTFIELD(Blocked, FALSE);
        exit(ICGLAccount."Map-to G/L Acc. No.");
    end;


    local procedure TryToGetDimensionsFromICPartnerDimensions(var DimJson: text)
    var
        DimensionValueTemp: Record "Dimension Value" temporary;
    begin
        GetDimensionsFromJSON(DimJson, DimensionValueTemp);
        ReplaceDimensionsWithMappedFromIC(DimensionValueTemp);
        ConvertDimensionsToJson(DimJson, DimensionValueTemp);
    end;

    local procedure GetDimensionsFromJSON(DimJson: text; var DimensionValueTemp: Record "Dimension Value" temporary)
    var
        Jarr: JsonArray;
        i: Integer;
        Jtoken: JsonToken;
        Jobj: JsonObject;
    begin
        If not JArr.ReadFrom(DimJson) then
            exit;
        DimensionValueTemp.DeleteAll();
        For i := 0 to Jarr.Count - 1 do begin
            Jarr.Get(i, Jtoken);
            Jobj := Jtoken.AsObject;
            DimensionValueTemp.Init();
            DimensionValueTemp."Dimension Code" := GetJsonValueAsCode(Jobj, 'code');
            DimensionValueTemp.Code := GetJsonValueAsCode(Jobj, 'valueCode');
            DimensionValueTemp.Insert();
        end;
    end;

    local procedure ReplaceDimensionsWithMappedFromIC(var DimensionValueTemp: Record "Dimension Value" temporary)
    var
        DimCode: Code[20];
        DimValue: Code[20];
    begin
        if DimensionValueTemp.FindSet(true, true) then
            repeat
                DimCode := DimensionValueTemp."Dimension Code";
                DimValue := DimensionValueTemp.Code;

                GetDimensionFromICDimensions(DimCode, DimValue);
                DimensionValueTemp.Rename(DimCode, DimValue);
            until DimensionValueTemp.Next = 0;
    end;

    local procedure ConvertDimensionsToJSON(var DimJson: text; var DimensionValueTemp: Record "Dimension Value" temporary)
    var
        Jarr: JsonArray;
        Jobj: JsonObject;
    begin
        if DimensionValueTemp.FindSet() then
            repeat
                AddToJSONArray(Jarr, DimensionValueTemp);
            until DimensionValueTemp.Next = 0;
        Jarr.WriteTo(DimJson);
    End;


    local procedure GetDimensionFromICDimensions(var DimCode: code[20]; var DimValue: code[20])
    var
        ICDimensionValue: Record "IC Dimension Value";
    begin
        if Not ICDimensionValue.Get(DimCode, DimValue) then
            exit;
        DimCode := ICDimensionValue."Map-to Dimension Code";
        DimValue := ICDimensionValue."Map-to Dimension Value Code";
    end;

    local procedure AddToJSONArray(var Jarr: JsonArray; var DimensionValueTemp: Record "Dimension Value" temporary)
    var
        Jobj: JsonObject;
    begin
        Jobj.Add('code', DimensionValueTemp."Dimension Code");
        Jobj.Add('valueCode', DimensionValueTemp.Code);
        Jarr.Add(Jobj);
    end;

    local procedure GetJsonValueAsCode(var JsonObject: JsonObject; Property: text) Value: Code[20];
    var
        JsonValue: JsonValue;
    begin
        if not GetJsonValue(JsonObject, Property, JsonValue) then EXIT;
        Value := JsonValue.AsCode();
    end;

    local procedure GetJsonValue(var JsonObject: JsonObject;
    Property: text;
    var JsonValue: JsonValue): Boolean;
    var
        JsonToken: JsonToken;
    begin
        if not JsonObject.Get(Property, JsonToken) then exit;
        JsonValue := JsonToken.AsValue;
        Exit(true);
    end;
}