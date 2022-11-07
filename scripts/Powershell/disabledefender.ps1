Set-MpPreference -DisableRealtimeMonitoring $true -SubmitSamplesConsent NeverSend
Get-MpPreference -Verbose