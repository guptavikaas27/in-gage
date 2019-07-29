public class SurveyController {
    public final String SINGLE_OPTION_VERTICAL {get;set;}
    public final String SINGLE_OPTION_HORIZONTAL {get;set;}
    public final String MULTI_OPTION {get;set;}
    public final String TEXT_OPTION {get;set;}
    public final String NPS_SQUAREBOX {get;set;}
    public Integer questionNumber {get;set;}
    public Boolean isLiveChat {get;set;}
    public Boolean isNext {get;set;}
    public Boolean isPrevious {get;set;}
    public Boolean isSubmit{get;set;}
    public String surveyType {get;set;}
    public String backgroundImage {get;set;}
    public Survey__c survey{get;set;}
    public Survey_Question__c question {get;set;}
    public List<Survey_Question__c> childQuestionsList {get;set;}
    public List<SelectOption> surveyOptions {get;set;}
    public Map<Id, Survey_Option__c> mapOfSurveyOptions {get;set;}
    public String selectedAnswerId{get;set;}
    public String[] selectedAnswerIds = new String[]{};
    public String responsedAnswer{get;set;}
    public List<ResponseWrapper> listOfResponseWrapper {get;set;}
    public Map<Id, ResponseWrapper> mapOfResponses;
    public Map<Integer, Id> responseMap;
    public Map<String, String> childResponse{get;set;}
    public String childResponseString {get;set;}
    private ingage_Application_Settings__c setting = ingage_Application_Settings__c.getOrgDefaults();
    
    public SurveyController() {
        Id surveyId = Apexpages.currentPage().getParameters().get('id');
        isLiveChat = Apexpages.currentPage().getParameters().get('source') == 'livechat';
        questionNumber = 1;
        isSubmit = false;
        mapOfResponses = new Map<Id, ResponseWrapper>();
        responseMap = new Map<Integer, Id>();
        SINGLE_OPTION_VERTICAL = 'Single Select--Vertical';
        SINGLE_OPTION_HORIZONTAL = 'Single Select--Horizontal';
        MULTI_OPTION = 'Multi-Select--Vertical';
        TEXT_OPTION = 'Free Text';
        NPS_SQUAREBOX = 'NPS Square Box';
        survey = [
            SELECT Id, Submit_Response__c, First_Question__r.Id, First_Question__r.Question__c, First_Question__r.Type__c, First_Question__r.Required__c,
            	First_Question__r.Default_Next_Question__c, First_Question__r.Is_Parent__c, First_Question__r.Slider_Min_Range__c,
            	First_Question__r.Slider_Max_Range__c, Background_Image_URL__c
            FROM Survey__c
            WHERE Id = :surveyId
        ];
        backgroundImage = survey.Background_Image_URL__c != null ? survey.Background_Image_URL__c : setting.Survey_Site_Background_Image_URL__c;
        if(isLiveChat) {
            initLiveChat();
        } else {
            init();
        }
    }
    
    public void init() {
        question = survey.First_Question__r;
        if(question.Is_Parent__c) {
            childQuestionsList = [
                SELECT Id, Question__c, Type__c, Required__c, Slider_Min_Range__c, Slider_Max_Range__c
                FROM Survey_Question__c
                WHERE Parent_Question__c = :question.Id
            ];
        } else if(!TEXT_OPTION.equalsIgnoreCase(question.Type__c)) {
            surveyOptions = fetchSurveyOptionByQuestion(question.Id);
        }
        checkIfQuestionLeft();
        childResponse = new Map<String, String>{'hello'=> 'hi'};
        childResponseString = JSON.serialize(childResponse);
    }
    
    public void initLiveChat() {
        Map<Id, Survey_Question__c> mapOfQuestionIdToQuestion = new Map<Id, Survey_Question__c>([
            SELECT Id, Question__c, Is_Parent__c, Type__c, Default_Next_Question__c, Required__c, Parent_Question__c,
            	Slider_Min_Range__c, Slider_Max_Range__c
            FROM Survey_Question__c
            WHERE Survey__c = :survey.Id
        ]);
        Id questionId = survey.First_Question__r.Id;
        Map<Id, List<SelectOption>> mapOfQuestionIdToSurveyOption = fetchSurveyOptionByQuestion(mapOfQuestionIdToQuestion.keySet());
        ResponseWrapper response;
        Map<Id, List<ResponseWrapper>> mapOfQuestionIdToChild = new Map<Id, List<ResponseWrapper>>();
        for(Survey_Question__c ques : mapOfQuestionIdToQuestion.values()) {
            if(ques.Parent_Question__c != null) {
                if(mapOfQuestionIdToChild.containsKey(ques.Parent_Question__c)){
                    List<ResponseWrapper> surveyQues = mapOfQuestionIdToChild.get(ques.Parent_Question__c);
                    response = new ResponseWrapper();
                    response.question = ques;
                    surveyQues.add(response);
                    mapOfQuestionIdToChild.put(ques.Parent_Question__c, surveyQues);
                } else {
                    response = new ResponseWrapper();
                    response.question = ques;
                    mapOfQuestionIdToChild.put(ques.Parent_Question__c, new List<ResponseWrapper>{response});
                }
            }
        }
        listOfResponseWrapper = new List<ResponseWrapper>();
        while(questionId != null) {
            response = new ResponseWrapper();
            response.questionId = questionId;
            response.isParent = mapOfQuestionIdToQuestion.get(questionId).Is_Parent__c;
            response.question = mapOfQuestionIdToQuestion.get(questionId);
            response.questionType = response.question.Type__c;
            response.surveyOptions = mapOfQuestionIdToSurveyOption.get(questionId);
            response.childResponseWrapper = mapOfQuestionIdToChild.get(questionId);
            response.optionIds = new String[]{};
            listOfResponseWrapper.add(response);
            questionId = response.question.Default_Next_Question__c;
        }
        system.debug(listOfResponseWrapper);
    }
    
    public List<SelectOption> fetchSurveyOptionByQuestion(Id questionId) {
        List<Survey_Option__c> options = [
            SELECT Id, Option__c, Next_Question__c
            FROM Survey_Option__c WHERE Survey_Question__c = :questionId ORDER BY Order_Number__c ASC
        ];
        mapOfSurveyOptions = new Map<Id, Survey_Option__c>(options);
        List<SelectOption> selectOptions = new List<SelectOption>();
        for(Survey_Option__c option : options) {
            selectOptions.add(new SelectOption(option.Id, option.Option__c));
        }
        return selectOptions;
    }
    
    public Map<Id, List<SelectOption>> fetchSurveyOptionByQuestion(Set<Id> questionId) {
        List<Survey_Option__c> options = [
            SELECT Id, Option__c, Survey_Question__c, Next_Question__c
            FROM Survey_Option__c WHERE Survey_Question__c IN :questionId ORDER BY Survey_Question__c, Order_Number__c ASC
        ];
        Map<Id, List<Survey_Option__c>> surveyOptionMap = new Map<Id, List<Survey_Option__c>>();
        for(Survey_Option__c option : options) {
            if(surveyOptionMap.containsKey(option.Survey_Question__c)) {
                List<Survey_Option__c> tempOptions = surveyOptionMap.get(option.Survey_Question__c);
                tempOptions.add(option);
                surveyOptionMap.put(option.Survey_Question__c, tempOptions);
            } else {
                surveyOptionMap.put(option.Survey_Question__c, new List<Survey_Option__c>{option});
            }
        }
        mapOfSurveyOptions = new Map<Id, Survey_Option__c>(options);
        List<SelectOption> selectOptions;
        surveyOptions = new List<SelectOption>();
        Map<Id, List<SelectOption>> mapOfQuestionIdToSurveyOption = new Map<Id, List<SelectOption>>();
        for(Id quesId : surveyOptionMap.keySet()) {
            selectOptions = new List<SelectOption>();
            for(Survey_Option__c option : surveyOptionMap.get(quesId)) {
                selectOptions.add(new SelectOption(option.Id, option.Option__c));
            }
            mapOfQuestionIdToSurveyOption.put(quesId, selectOptions);
            surveyOptions.addAll(selectOptions);
        }
        return mapOfQuestionIdToSurveyOption;
    }
    
    public void checkIfQuestionLeft() {
        if(question.Default_Next_Question__c != null) {
            isNext = true;
        } else {
            isNext = false;
        }
    }
    
    public Map<String, String> deserialize(String strResponse) {
        Map<String, Object> response = (Map<String, Object>)JSON.deserializeUntyped(strResponse);
        Map<String, String> mapOfResponse = new Map<String, String>();
        for(String str : response.keySet()){
            mapOfResponse.put(str, String.valueOf(response.get(str)));
        }
        return mapOfResponse;
    }
    
    public Boolean saveResponse() {
        Boolean isAnswered = false;
        ResponseWrapper response = new ResponseWrapper();
        response.questionId = question.Id;
        response.questionType = question.Type__c;
        response.isParent = question.Is_Parent__c;
        system.debug(responsedAnswer);
        if(question.Is_Parent__c) {
            childResponse = deserialize(childResponseString);
            response.childResponse = childResponse.clone();
            childResponse = null;
            childResponseString = '{}';
            isAnswered = true;
        } else {
            if(TEXT_OPTION.equalsIgnoreCase(question.Type__c)) {
                response.response = responsedAnswer;
                if(!String.isBlank(responsedAnswer)) {
                    isAnswered = true;
                }
            } else if(MULTI_OPTION.equalsIgnoreCase(question.Type__c)){
                response.optionId = String.join(selectedAnswerIds, ';');
                response.response = getResponseFromOption(selectedAnswerIds, surveyOptions);
                if(!String.isBlank(response.optionId)) {
                    isAnswered = true;
                }
            } else {
                response.response = getResponseFromOption(selectedAnswerId, surveyOptions);
                if('Other'.equalsIgnoreCase(response.response)){
                    response.response = responsedAnswer;
                }
                response.optionId = selectedAnswerId;
                if(!String.isBlank(selectedAnswerId)) {
                    if(!'Other'.equalsIgnoreCase(response.response) || !String.isBlank(responsedAnswer)) {
                        isAnswered = true;
                    }
                }
            }
        }
        if(question.Required__c) {
            if(!isAnswered) {
                return false;
            }
        }
        mapOfResponses.put(question.Id, response);
        responseMap.put(questionNumber, question.Id);
        questionNumber++;
        return true;
    }
    
    public void nextQuestion() {
        Boolean isContinueToNext = saveResponse();
        if(!isContinueToNext) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.Error, 'Response is required for this question.'));
            return;
        }
        isPrevious = true;
        Id nextQuestionId;
        if(question.Is_Parent__c) {
            nextQuestionId = null;
        } else if(MULTI_OPTION.equalsIgnoreCase(question.Type__c)){
            Set<Id> nextIds = new Set<Id>();
            for(Id optionId : mapOfSurveyOptions.keySet()) {
                if(selectedAnswerIds.contains(optionId)) {
                    nextIds.add(mapOfSurveyOptions.get(optionId).Next_Question__c);
                }
            }
            if(nextIds.size() == 1) {
                nextQuestionId = new List<Id>(nextIds)[0];
            }
        } else if(!TEXT_OPTION.equalsIgnoreCase(question.Type__c)) {
            nextQuestionId = mapOfSurveyOptions.get(selectedAnswerId) == null ? null : mapOfSurveyOptions.get(selectedAnswerId).Next_Question__c;
        }
        if(nextQuestionId == null) {
            nextQuestionId = question.Default_Next_Question__c;
        }
        selectedAnswerId = null;
        selectedAnswerIds = new String[]{};
        responsedAnswer = null;
        question = null;
        if(nextQuestionId != null) {
            question = [
                SELECT Id, Question__c, Is_Parent__c, Type__c, Default_Next_Question__c, Required__c, Slider_Min_Range__c, Slider_Max_Range__c
                FROM Survey_Question__c
                WHERE Id = :nextQuestionId
            ];
            if(question.Is_Parent__c) {
                childQuestionsList = [
                    SELECT Id, Question__c, Type__c, Required__c, Slider_Min_Range__c, Slider_Max_Range__c
                    FROM Survey_Question__c
                    WHERE Parent_Question__c = :question.Id
                ];
            } else if(!TEXT_OPTION.equalsIgnoreCase(question.Type__c)) {
                surveyOptions = fetchSurveyOptionByQuestion(question.Id);
            }
            checkIfQuestionLeft();
            if(mapOfResponses.get(question.Id) != null) {
                if(question.Is_Parent__c) {
                    childResponse = mapOfResponses.get(question.Id).childResponse;
                    childResponseString = JSON.serialize(childResponse);
                } else if(MULTI_OPTION.equalsIgnoreCase(mapOfResponses.get(question.Id).questionType)) {
                    selectedAnswerIds = mapOfResponses.get(question.Id).optionId.split(';');
                    selectedAnswerId = null;
                    responsedAnswer = null;
                } else {
                    selectedAnswerIds = new String[]{};
                    selectedAnswerId = mapOfResponses.get(question.Id).optionId;
                    String optionResponse = getResponseFromOption(selectedAnswerId, surveyOptions);
                    if(optionResponse == 'Other') {
                        responsedAnswer = mapOfResponses.get(question.Id).response;
                    } else {
                        responsedAnswer = '';
                    }
                }
            }
        }
    }
    
    public void previousQuestion() {
        questionNumber--;
        if(questionNumber < 2) {
            isPrevious = false;
        }
        question = [
            SELECT Id, Question__c, Type__c, Default_Next_Question__c, Is_Parent__c, Required__c, Slider_Min_Range__c, Slider_Max_Range__c
            FROM Survey_Question__c
            WHERE Id = :mapOfResponses.get(responseMap.get(questionNumber)).questionId
        ];
        if(question.Is_Parent__c) {
            childQuestionsList = [
                SELECT Id, Question__c, Type__c, Required__c, Slider_Min_Range__c, Slider_Max_Range__c
                FROM Survey_Question__c
                WHERE Parent_Question__c = :question.Id
            ];
            childResponse = mapOfResponses.get(responseMap.get(questionNumber)).childResponse;
            childResponseString = JSON.serialize(childResponse);
        } else{
            if(!TEXT_OPTION.equalsIgnoreCase(question.Type__c)) {
                surveyOptions = fetchSurveyOptionByQuestion(question.Id);
            }
            if(MULTI_OPTION.equalsIgnoreCase(question.Type__c)){
                selectedAnswerIds = mapOfResponses.get(responseMap.get(questionNumber)).optionId.split(';');
                selectedAnswerId = null;
                responsedAnswer = null;
            } else{
                selectedAnswerIds = new String[]{};
                selectedAnswerId = mapOfResponses.get(responseMap.get(questionNumber)).optionId;
                String optionResponse = getResponseFromOption(selectedAnswerId, surveyOptions);
                if(optionResponse == 'Other') {
                    responsedAnswer = mapOfResponses.get(question.Id).response;
                } else {
                    responsedAnswer = '';
                }
            }
        }
        isNext = true;
    }
    
    public void submitChatSurvey() {
        SurveyTaker__c taker = new SurveyTaker__c();
        taker.User__c = UserInfo.getUserId();
        taker.Survey__c = survey.Id;
        insert taker;
        List<SurveyQuestionResponse__c> listOfSurveyResponse = new List<SurveyQuestionResponse__c>();
        SurveyQuestionResponse__c surveyResponse;
        for(ResponseWrapper wrap : listOfResponseWrapper) {
            if(!wrap.question.Is_Parent__c) {
                surveyResponse = new SurveyQuestionResponse__c();
                surveyResponse.Survey_Question__c = wrap.question.Id;
                if(TEXT_OPTION.equalsIgnoreCase(wrap.question.Type__c)) {
                    surveyResponse.Response__c = wrap.response;
                } else if(MULTI_OPTION.equalsIgnoreCase(wrap.question.Type__c)){
                    surveyResponse.Response__c = getResponseFromOption(wrap.optionIds, surveyOptions);
                } else {
                    surveyResponse.Response__c = getResponseFromOption(wrap.optionId, surveyOptions);
                    if('Other'.equalsIgnoreCase(surveyResponse.Response__c)){
                        surveyResponse.Response__c = wrap.response;
                    }
                }
                surveyResponse.SurveyTaker__c = taker.Id;
                listOfSurveyResponse.add(surveyResponse);
            }
        }
        childResponse = deserialize(childResponseString);
        for(String questionId : childResponse.keySet()) {
            surveyResponse = new SurveyQuestionResponse__c();
            surveyResponse.Survey_Question__c = questionId;
            surveyResponse.Response__c = childResponse.get(questionId);
            surveyResponse.SurveyTaker__c = taker.Id;
            listOfSurveyResponse.add(surveyResponse);
        }
        if(listOfSurveyResponse.size() > 0) {
            insert listOfSurveyResponse;
        }
        system.debug(listOfSurveyResponse);
        isSubmit = true;
    }
    
    public void submitSurvey() {
        Boolean isContinueToNext = saveResponse();
        if(!isContinueToNext) {
            ApexPages.addmessage(new ApexPages.message(ApexPages.severity.Error, 'Response is required for this question.'));
            return;
        }
        isSubmit = true;
        saveSurveyResponse();
    }
    
    public void saveSurveyResponse() {
        SurveyTaker__c taker = new SurveyTaker__c();
        taker.User__c = UserInfo.getUserId();
        taker.Survey__c = survey.Id;
        insert taker;
        List<SurveyQuestionResponse__c> listOfSurveyResponse = new List<SurveyQuestionResponse__c>();
        SurveyQuestionResponse__c surveyResponse;
        for(Id questionId : responseMap.values()) {
            if(mapOfResponses.get(questionId).isParent) {
                for(String str : mapOfResponses.get(questionId).childResponse.keySet()) {
                    surveyResponse = new SurveyQuestionResponse__c();
                    surveyResponse.Survey_Question__c = str;
                    surveyResponse.Response__c = mapOfResponses.get(questionId).childResponse.get(str);
                    surveyResponse.SurveyTaker__c = taker.Id;
                    listOfSurveyResponse.add(surveyResponse);
                }
            } else {
                surveyResponse = new SurveyQuestionResponse__c();
                surveyResponse.Survey_Question__c = mapOfResponses.get(questionId).questionId;
                surveyResponse.Response__c = mapOfResponses.get(questionId).response;
                surveyResponse.SurveyTaker__c = taker.Id;
                listOfSurveyResponse.add(surveyResponse);
            }
        }
        insert listOfSurveyResponse;
    }
    
    public String getResponseFromOption(String selectedId, List<SelectOption> selectOptions) {
        for(SelectOption option : selectOptions) {
            if(selectedId == option.getValue()) {
                return option.getLabel();
            }
        }
        return null;
    }
    
    public String getResponseFromOption(String[] selectedIds, List<SelectOption> selectOptions) {
        List<String> ids = new List<String>();
        for(String str : selectedIds) {
            for(SelectOption option : selectOptions) {
                if(str == option.getValue()) {
                    ids.add(option.getLabel());
                    continue;
                }
            }
        }
        return String.join(ids, ';');
    }
    
    public class ResponseWrapper {
        public Id questionId;
        public Survey_Question__c question {get;set;}
        public String optionId{get;set;}
        public String[] optionIds{get;set;}
        public List<SelectOption> surveyOptions{get;set;}
        public String questionType;
        public String response{get;set;}
        public Boolean isSkipped;
        public Boolean isParent;
        public List<ResponseWrapper> childResponseWrapper {get;set;}
        public Map<String, String> childResponse{get;set;}
    }
    
    public List<String> getSelectedAnswerIds() {
        return selectedAnswerIds;
    }
    
    public void setSelectedAnswerIds(List<String> selectedAnswerIds) {
        this.selectedAnswerIds = selectedAnswerIds;
    }
}