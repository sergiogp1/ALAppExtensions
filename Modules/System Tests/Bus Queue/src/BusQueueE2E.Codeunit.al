codeunit 51750 "Bus Queue E2E"
{
    Access = Public;
    Subtype = Test;

    var
        BusQueue: Codeunit "Bus Queue";
        LibraryAssert: Codeunit "Library Assert";
        NonExistingUrlTxt: Label 'https://www.e89b2cb3d714451c94f03b617b5fd6824109b0cfef864576a3b5e7febadfe39b.com', Locked = true;
        MicrosoftUrlTxt: Label 'https://www.microsoft.com', Locked = true;

    [Test]
    procedure TestExistingURLIsProcessed()
    var
        BusQueueRec: Record "Bus Queue";
        BusQueueEntryNo: Integer;
    begin
        // [SCENARIO] Enqueues a bus queue with an existing URL and status must be Processed
        
        // [GIVEN] One bus queue
        BusQueue.Init(MicrosoftUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(false);
        Initialize();

        // [WHEN] Bus queue is processed
        BusQueueEntryNo := BusQueue.Enqueue();
        
        // [THEN] The bus queue status must be Processed
        BusQueueRec.Get(BusQueueEntryNo);
        LibraryAssert.AreEqual(BusQueueRec.Status, BusQueueRec.Status::Processed, 'Status must be Processed');        
    end;

    [Test]
    procedure TestNonExistingURLIsError()
    var
        BusQueueRec: Record "Bus Queue";
        BusQueueEntryNo: Integer;
    begin
        // [SCENARIO] Enqueues a bus queue with a non existing URL and status must be Error

        // [GIVEN] One bus queue
        BusQueue.Init(NonExistingUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(false);
        Initialize();

        // [WHEN] Bus queue is processed
        BusQueueEntryNo := BusQueue.Enqueue();

        // [THEN] The bus queue status must be Error
        BusQueueRec.Get(BusQueueEntryNo);
        LibraryAssert.AreEqual(BusQueueRec.Status, BusQueueRec.Status::Error, 'Status must be Error');
    end;

    [Test]
    procedure TestBusQueueIsReadInTheSameEncoding()
    var
        BusQueueRec: Record "Bus Queue";
        DotNetEncoding: Codeunit DotNet_Encoding;
        DotNetStreamReader: Codeunit DotNet_StreamReader;
        BusQueueEntryNo: Integer;
        InStream: InStream;
        BusQueueBody, JapaneseCharactersTok: Text;
    begin
        // [SCENARIO] Enqueues a bus queue with a specific codepage. Body of the bus queue must be read in the same codepage.

        // [GIVEN] Some non English characters 
        JapaneseCharactersTok := 'こんにちは世界'; //Hello world in Japanese

        // [WHEN] Bus queue is enqueued
        BusQueue.Init(MicrosoftUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetBody(JapaneseCharactersTok, 932); //Japanese (Shift-JIS)
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(false);
        Initialize();

        // [THEN] The body must be read in the same codepage
        BusQueueEntryNo := BusQueue.Enqueue();
        BusQueueRec.SetAutoCalcFields(Body);
        BusQueueRec.Get(BusQueueEntryNo);
        BusQueueRec.Body.CreateInStream(InStream);
        DotNetEncoding.Encoding(BusQueueRec.Codepage);
        DotNetStreamReader.StreamReader(InStream, DotNetEncoding);
        BusQueueBody := DotNetStreamReader.ReadToEnd();

        LibraryAssert.AreEqual(BusQueueBody, JapaneseCharactersTok, 'Read body is not equal to ' + JapaneseCharactersTok);
    end;

    [Test]
    procedure TestMaximumThreeTriesAreRun()
    var
        BusQueueRec: Record "Bus Queue";
        BusQueueEntryNo: Integer;
    begin
        // [SCENARIO] Enqueues a bus queue and only three tries must be run
        
        // [GIVEN] One bus queue
        BusQueue.Init(NonExistingUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(false);
        Initialize();

        // [WHEN] Bus queue is processed
        BusQueueEntryNo := BusQueue.Enqueue();
        
        // [THEN] The bus queue number of tries must be three
        BusQueueRec.Get(BusQueueEntryNo);
        LibraryAssert.AreEqual(BusQueueRec."No. Of Tries", 3, 'No. of tries does not equal 3');
    end;

    [Test]
    procedure TestTwoSecondsElapse()
    var
        BusQueueRec: Record "Bus Queue";
        BusQueueEntryNo: Integer;
        BeforeRunDateTime, AfterRunDateTime: DateTime;
    begin
        // [SCENARIO] Enqueues a bus queue and very approximately only two seconds must elapse after three tries
        
        // [GIVEN] One bus queue
        BusQueue.Init(NonExistingUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(false);
        Initialize();

        // [WHEN] Bus queue is processed
        BeforeRunDateTime := CurrentDateTime();
        BusQueueEntryNo := BusQueue.Enqueue();
        AfterRunDateTime := CurrentDateTime();
        
        // [THEN] The bus queue status must be Processed
        BusQueueRec.Get(BusQueueEntryNo);
        LibraryAssert.AreNearlyEqual(2, (AfterRunDateTime - BeforeRunDateTime) / 1000, 1, 'More than 3 seconds elapsed');
    end;

    [Test]
    procedure TestItIsPossibleToRetrieveResponse()
    var
        BusQueueRec: Record "Bus Queue";
        BusQueueTestSubscriber: Codeunit "Bus Queue Test Subscriber";
        BusQueueEntryNo: Integer;
    begin
        // [SCENARIO] Enqueues a bus queue and response must be retrieved through event subscription

        // [GIVEN] One bus queue
        if BindSubscription(BusQueueTestSubscriber) then;
        BusQueueTestSubscriber.ClearReasonPhrase();
        BusQueue.Init(NonExistingUrlTxt, Enum::"Http Request Type"::GET);
        BusQueue.SetRaiseOnAfterInsertBusQueueResponse(true);
        Initialize();

        // [WHEN] Bus queue is processed
        BusQueueEntryNo := BusQueue.Enqueue();
        
        // [THEN] The reason phrase must not be empty
        BusQueueRec.Get(BusQueueEntryNo);
        LibraryAssert.AreNotEqual('', BusQueueTestSubscriber.GetReasonPhrase(), 'Response''s reason phrase is empty');
    end;

    local procedure Initialize()
    begin
        BusQueue.SetSecondsBetweenRetries(1);
        BusQueue.SetMaximumNumberOfTries(3);
        BusQueue.SetUseTaskScheduler(false);        
    end;
}