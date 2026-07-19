Imports System.Text.RegularExpressions

Public NotInheritable Class ParsePattern
    Private Shared ReadOnly TokenParsingRegex As New Regex(
        "(\\[%@$*#&?!-]|[%@$*#&?!-]\{.*?\}|[%@$*#&?!-])",
        RegexOptions.Compiled)

    Private Shared ReadOnly LengthWithVariants As New Regex(
        "\{((\d+)-(\d+)|(\d+))\}",
        RegexOptions.Compiled)

    Private Shared ReadOnly LengthWithString As New Regex(
        "\{'(.*)'(?:,(\d+)-(\d+))?(?:,(\d+))?\}",
        RegexOptions.Compiled)

    Private Sub New()
    End Sub

    Private Shared Function ParseLengthWithVariants(part As String, variants As List(Of String)) As TokenOptions
        Dim match = LengthWithVariants.Match(part)
        Dim startLength = 1
        Dim endLength = 1

        If match.Success Then
            If match.Groups(2).Success AndAlso match.Groups(2).Value.Length > 0 Then
                startLength = Integer.Parse(match.Groups(2).Value)
                endLength = Integer.Parse(match.Groups(3).Value)
            ElseIf match.Groups(1).Success Then
                startLength = Integer.Parse(match.Groups(1).Value)
                endLength = startLength
            End If
        End If

        Return TokenOptions.Create(variants, startLength, endLength, part)
    End Function

    Private Shared Function ParseLengthWithString(part As String) As TokenOptions
        Dim match = LengthWithString.Match(part)
        If Not match.Success Then
            Return Nothing
        End If

        If match.Groups(2).Success AndAlso match.Groups(3).Success Then
            Return New TokenOptions With {
                .[String] = match.Groups(1).Value,
                .StartLength = Integer.Parse(match.Groups(2).Value),
                .EndLength = Integer.Parse(match.Groups(3).Value),
                .Src = part
            }
        End If

        If match.Groups(4).Success Then
            Dim length = Integer.Parse(match.Groups(4).Value)
            Return New TokenOptions With {
                .[String] = match.Groups(1).Value,
                .StartLength = length,
                .EndLength = length,
                .Src = part
            }
        End If

        Return New TokenOptions With {
            .[String] = match.Groups(1).Value,
            .StartLength = 1,
            .EndLength = 1,
            .Src = part
        }
    End Function

    Private Shared Function SimpleTokenizer(variantsString As String) As Func(Of String, Token)
        Dim variants = variantsString.Select(Function(c) c.ToString()).ToList()
        Return Function(part) New Token(ParseLengthWithVariants(part, variants))
    End Function

    Private Shared Function DictionaryTokenizer(part As String, dictionaries As IReadOnlyDictionary(Of String, List(Of String))) As Token
        Dim options = ParseLengthWithString(part)
        If options Is Nothing OrElse
           (Not String.IsNullOrEmpty(options.String) AndAlso Not dictionaries.ContainsKey(options.String)) Then
            Return New Token(TokenOptions.Create(New List(Of String) From {part}, 1, 1, part))
        End If

        Dim words As List(Of String) = Nothing
        If dictionaries.TryGetValue(If(options.String, ""), words) Then
            options.Variants = words
        Else
            options.Variants = New List(Of String)()
        End If
        Return New Token(options)
    End Function

    Private Shared Function WordsTokenizer(part As String) As Token
        Dim options = ParseLengthWithString(part)
        If options Is Nothing Then
            Return New Token(TokenOptions.Create(New List(Of String) From {part}, 1, 1, part))
        End If

        Dim variants As New List(Of String)()
        Dim workString = If(options.String, "")
        Dim index = 0
        While index < workString.Length
            If index + 1 < workString.Length AndAlso
               workString(index) = "\"c AndAlso
               workString(index + 1) = ","c Then
                index += 2
            ElseIf workString(index) = ","c Then
                variants.Add(workString.Substring(0, index))
                workString = workString.Substring(index + 1)
                index = 0
            Else
                index += 1
            End If
        End While
        variants.Add(workString)
        options.Variants = variants.Select(Function(v) v.Replace("\,", ",")).ToList()
        Return New Token(options)
    End Function

    Private Shared Function PartToToken(part As String, dictionaries As IReadOnlyDictionary(Of String, List(Of String))) As Token
        Dim tokenizers As New Dictionary(Of Char, Func(Of String, Token)) From {
            {"#"c, SimpleTokenizer("0123456789")},
            {"@"c, SimpleTokenizer("abcdefghijklmnopqrstuvwxyz")},
            {"*"c, SimpleTokenizer("abcdefghijklmnopqrstuvwxyz0123456789")},
            {"-"c, SimpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")},
            {"!"c, SimpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ")},
            {"?"c, SimpleTokenizer("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")},
            {"&"c, SimpleTokenizer("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")},
            {"%"c, Function(p) DictionaryTokenizer(p, dictionaries)},
            {"$"c, AddressOf WordsTokenizer}
        }

        Dim tokenizer As Func(Of String, Token) = Nothing
        Dim hasTokenizer = part.Length > 0 AndAlso tokenizers.TryGetValue(part(0), tokenizer)
        Dim isEscapedToken = part.Length > 1 AndAlso part(0) = "\"c AndAlso tokenizers.ContainsKey(part(1))

        If hasTokenizer AndAlso tokenizer IsNot Nothing Then
            Return tokenizer(part)
        End If

        If isEscapedToken Then
            Return New Token(TokenOptions.Create(New List(Of String) From {part.Substring(1)}, 1, 1, part))
        End If

        Return New Token(TokenOptions.Create(New List(Of String) From {part}, 1, 1, part))
    End Function

    Public Shared Function Parse(inputPattern As String, dictionaries As IReadOnlyDictionary(Of String, List(Of String))) As List(Of Token)
        Dim dicts = If(dictionaries, New Dictionary(Of String, List(Of String))())
        ' Capturing groups are included in .NET Regex.Split results (like JS/Python).
        Dim parts = TokenParsingRegex.Split(inputPattern).Where(Function(p) p.Length > 0)
        Return parts.Select(Function(part) PartToToken(part, dicts)).ToList()
    End Function
End Class

