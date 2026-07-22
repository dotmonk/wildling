@{
    RootModule        = 'Wildling.psm1'
    ModuleVersion = '2.0.2'
    GUID              = 'a7c3e8f1-2b4d-4e9a-9c1f-8d6e5a4b3c2d'
    Author            = 'dotmonk'
    CompanyName       = 'dotmonk'
    Copyright         = '(c) dotmonk. MIT License.'
    Description       = 'Pattern based string generator library and CLI'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('*')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('pattern', 'generator', 'wildcard', 'wordlist')
            LicenseUri   = 'https://github.com/dotmonk/wildling/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/dotmonk/wildling'
            ReleaseNotes = 'https://github.com/dotmonk/wildling/releases'
        }
    }
}
