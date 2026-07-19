Imports System.IO
Imports System.Text
Imports System.Text.Json

Public NotInheritable Class Cli
    Friend NotInheritable Class Range
        Public Sub New(start As Integer, [end] As Integer)
            Me.Start = start
            Me.End = [end]
        End Sub

        Public ReadOnly Property Start As Integer
        Public ReadOnly Property [End] As Integer
    End Class

    Friend NotInheritable Class CliArgs
        Public ReadOnly Property Selects As New List(Of Integer)()
        Public ReadOnly Property Ranges As New List(Of Range)()
        Public Property Check As Boolean
        Public ReadOnly Property Dictionaries As New Dictionary(Of String, List(Of String))()
        Public ReadOnly Property Patterns As New List(Of String)()
        Public Property Help As Boolean
        Public Property Version As Boolean
    End Class

    Private Sub New()
    End Sub

    Friend Shared Function ParseRange(value As String) As Range
        Dim dash = value.IndexOf("-"c)
        If dash <= 0 OrElse dash = value.Length - 1 Then
            Return Nothing
        End If

        Dim start As Integer
        Dim [end] As Integer
        If Not Integer.TryParse(value.Substring(0, dash), start) OrElse
           Not Integer.TryParse(value.Substring(dash + 1), [end]) Then
            Return Nothing
        End If

        If start <= [end] Then
            Return New Range(start, [end])
        End If
        Return Nothing
    End Function

    Friend Shared Function LoadDictionaryFile(path As String) As List(Of String)
        Return File.ReadAllLines(path, Encoding.UTF8).
            Select(Function(l) l.Trim()).
            Where(Function(l) l.Length > 0).
            ToList()
    End Function

    Friend Shared Sub ApplyDictionary(result As CliArgs, name As String, value As Object)
        If TypeOf value Is JsonElement Then
            Dim json = DirectCast(value, JsonElement)
            If json.ValueKind = JsonValueKind.Array Then
                Dim words As New List(Of String)()
                For Each item In json.EnumerateArray()
                    words.Add(item.ToString())
                Next
                result.Dictionaries(name) = words
                Return
            End If

            If json.ValueKind = JsonValueKind.String Then
                value = json.GetString()
            Else
                Return
            End If
        End If

        Dim list = TryCast(value, List(Of Object))
        If list IsNot Nothing Then
            result.Dictionaries(name) = list.Select(Function(v) If(v?.ToString(), "")).ToList()
            Return
        End If

        Dim path = value?.ToString()
        If Not String.IsNullOrEmpty(path) AndAlso File.Exists(path) Then
            Try
                result.Dictionaries(name) = LoadDictionaryFile(path)
            Catch ex As IOException
                ' ignore unreadable dictionary files
            End Try
        End If
    End Sub

    Friend Shared Sub ApplyTemplate(result As CliArgs, path As String)
        If Not File.Exists(path) Then
            Console.Error.WriteLine($"Template file not found: {path}")
            Environment.Exit(1)
        End If

        Dim document As JsonDocument = Nothing
        Try
            document = JsonDocument.Parse(File.ReadAllText(path, Encoding.UTF8))
        Catch
            Console.Error.WriteLine($"Invalid JSON template: {path}")
            Environment.Exit(1)
            Return
        End Try

        Using document
            If document.RootElement.ValueKind <> JsonValueKind.Object Then
                Console.Error.WriteLine($"Invalid JSON template: {path}")
                Environment.Exit(1)
            End If

            Dim root = document.RootElement

            Dim check As JsonElement
            If root.TryGetProperty("check", check) AndAlso check.ValueKind = JsonValueKind.True Then
                result.Check = True
            End If

            Dim [select] As JsonElement
            If root.TryGetProperty("select", [select]) AndAlso [select].ValueKind = JsonValueKind.Array Then
                For Each item In [select].EnumerateArray()
                    Dim number As Integer
                    If item.ValueKind = JsonValueKind.Number AndAlso item.TryGetInt32(number) Then
                        If number >= 0 Then result.Selects.Add(number)
                    ElseIf Integer.TryParse(item.ToString(), number) AndAlso number >= 0 Then
                        result.Selects.Add(number)
                    End If
                Next
            End If

            Dim ranges As JsonElement
            If root.TryGetProperty("range", ranges) AndAlso ranges.ValueKind = JsonValueKind.Array Then
                For Each rangeStr In ranges.EnumerateArray()
                    Dim parsed = ParseRange(rangeStr.ToString())
                    If parsed IsNot Nothing Then
                        result.Ranges.Add(parsed)
                    End If
                Next
            End If

            Dim dictionaries As JsonElement
            If root.TryGetProperty("dictionaries", dictionaries) AndAlso
               dictionaries.ValueKind = JsonValueKind.Object Then
                For Each entry In dictionaries.EnumerateObject()
                    ApplyDictionary(result, entry.Name, entry.Value)
                Next
            End If

            Dim patterns As JsonElement
            If root.TryGetProperty("patterns", patterns) AndAlso patterns.ValueKind = JsonValueKind.Array Then
                For Each pattern In patterns.EnumerateArray()
                    result.Patterns.Add(pattern.ToString())
                Next
            End If
        End Using
    End Sub

    Friend Shared Function ParseArgs(args As String()) As CliArgs
        Dim result As New CliArgs()
        Dim i = 0
        While i < args.Length
            Dim arg = args(i)

            If arg = "--help" OrElse arg = "-h" Then
                result.Help = True
                i += 1
                Continue While
            End If

            If arg = "--version" OrElse arg = "-v" Then
                result.Version = True
                i += 1
                Continue While
            End If

            If arg = "--check" Then
                result.Check = True
                i += 1
                Continue While
            End If

            If arg = "--select" Then
                i += 1
                If i >= args.Length Then Exit While
                Dim selected As Integer
                If Integer.TryParse(args(i), selected) AndAlso selected >= 0 Then
                    result.Selects.Add(selected)
                End If
                i += 1
                Continue While
            End If

            If arg = "--range" Then
                i += 1
                If i >= args.Length Then Exit While
                Dim parsed = ParseRange(args(i))
                If parsed IsNot Nothing Then
                    result.Ranges.Add(parsed)
                End If
                i += 1
                Continue While
            End If

            If arg = "--dictionary" Then
                i += 1
                If i >= args.Length Then Exit While
                Dim spec = args(i)
                Dim colon = spec.IndexOf(":"c)
                If colon > 0 AndAlso colon < spec.Length - 1 Then
                    ApplyDictionary(result, spec.Substring(0, colon), spec.Substring(colon + 1))
                End If
                i += 1
                Continue While
            End If

            If arg = "--template" Then
                i += 1
                If i >= args.Length Then
                    Console.Error.WriteLine("Missing path for --template")
                    Environment.Exit(1)
                End If
                ApplyTemplate(result, args(i))
                i += 1
                Continue While
            End If

            result.Patterns.Add(arg)
            i += 1
        End While

        Return result
    End Function

    Friend Shared Function LoadHelpText() As String
        Dim candidates As String() = {
            Path.Combine(AppContext.BaseDirectory, "help.txt"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "help.txt"),
            Path.Combine("docs", "help.txt")
        }

        For Each helpPath In candidates
            If File.Exists(helpPath) Then
                Return File.ReadAllText(helpPath, Encoding.UTF8)
            End If
        Next

        Return "wildling - pattern based string generator" & vbLf & vbLf & "Help text unavailable." & vbLf
    End Function

    Friend Shared Function FormatList(values As IEnumerable(Of Object)) As String
        Dim list = values.ToList()
        If list.Count = 0 Then
            Return ""
        End If
        Return " " & String.Join(" ", list)
    End Function

    Friend Shared Function FormatCheckOutput(args As CliArgs, total As Integer, generators As IReadOnlyList(Of Generator)) As String
        Dim lines As New List(Of String) From {
            $"patterns:{FormatList(args.Patterns.Cast(Of Object)())}",
            $"dictionaries:{FormatList(args.Dictionaries.Keys.Cast(Of Object)())}",
            $"select:{FormatList(args.Selects.Cast(Of Object)())}",
            $"range:{FormatList(args.Ranges.Select(Function(r) $"{r.Start}-{r.End}").Cast(Of Object)())}",
            $"total: {total}"
        }
        For Each gen In generators
            lines.Add($"generator: {gen.Source} {gen.Count()}")
        Next
        Return String.Join(vbLf, lines)
    End Function

    ''' <summary>True when value is the typed Boolean false sentinel.</summary>
    Friend Shared Function IsFalse(value As Object) As Boolean
        Return TypeOf value Is Boolean AndAlso Not CBool(value)
    End Function

    Public Shared Function Run(args As String()) As Integer
        Dim parsed = ParseArgs(args)

        If parsed.Help Then
            Console.WriteLine(LoadHelpText().TrimEnd())
            Return 0
        End If

        If parsed.Version Then
            Console.WriteLine($"wildling {Wildling.Version}")
            Return 0
        End If

        If parsed.Patterns.Count = 0 Then
            Console.Error.WriteLine("No pattern provided. Use --help for usage information.")
            Return 1
        End If

        Dim wildcard = Wildling.Create(parsed.Patterns, parsed.Dictionaries)

        If parsed.Check Then
            Console.WriteLine(FormatCheckOutput(parsed, wildcard.Count(), wildcard.Generators()))
            Return 0
        End If

        If parsed.Selects.Count > 0 OrElse parsed.Ranges.Count > 0 Then
            Dim oor = False
            For Each index In parsed.Selects
                Dim selected = wildcard.Get(index)
                If IsFalse(selected) Then
                    Console.Error.WriteLine($"out of range: {index}")
                    oor = True
                Else
                    Console.WriteLine(selected)
                End If
            Next
            For Each range In parsed.Ranges
                For index = range.Start To range.End
                    Dim selected = wildcard.Get(index)
                    If IsFalse(selected) Then
                        Console.Error.WriteLine($"out of range: {index}")
                        oor = True
                    Else
                        Console.WriteLine(selected)
                    End If
                Next
            Next
            Return If(oor, 1, 0)
        End If

        Dim value = wildcard.Next()
        While Not IsFalse(value)
            Console.WriteLine(value)
            value = wildcard.Next()
        End While

        Return 0
    End Function
End Class

