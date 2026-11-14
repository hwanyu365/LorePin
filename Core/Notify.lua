local _, ns = ...

-- 저장·실행해야 알 수 있는 실패. 채팅창은 대화에 묻히므로 WoW 기본 오류와 같은 화면 상단에도 띄운다.
function ns:NotifyError(msg)
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1)
    end
    self:Print(msg)
end
