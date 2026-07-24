Public NotInheritable Class Wildling
    Public Const Version As String = "2.0.3"

    Private ReadOnly _generators As List(Of Generator)
    Private ReadOnly _patternCount As Integer
    Private _internalIndex As Integer

    Public Sub New(patterns As IEnumerable(Of String), Optional dictionaries As IReadOnlyDictionary(Of String, List(Of String)) = Nothing)
        Dim dicts = If(dictionaries, New Dictionary(Of String, List(Of String))())
        _generators = New List(Of Generator)()
        Dim total = 0
        For Each pattern In patterns
            Dim generator As New Generator(pattern, dicts)
            _generators.Add(generator)
            total += generator.Count()
        Next
        _patternCount = total
        _internalIndex = 0
    End Sub

    Public Shared Function Create(
        patterns As IEnumerable(Of String),
        Optional dictionaries As IReadOnlyDictionary(Of String, List(Of String)) = Nothing) As Wildling
        Return New Wildling(patterns, dictionaries)
    End Function

    Public Function Index() As Integer
        Return _internalIndex
    End Function

    Public Function Count() As Integer
        Return _patternCount
    End Function

    Public Sub Reset()
        _internalIndex = 0
    End Sub

    ''' <summary>Next combination, or <c>false</c> when exhausted.</summary>
    Public Function [Next]() As Object
        If _internalIndex = _patternCount Then
            Return False
        End If
        _internalIndex += 1
        Return [Get](_internalIndex - 1)
    End Function

    Public Function Generators() As IReadOnlyList(Of Generator)
        Return _generators
    End Function

    ''' <summary>Combination at index, or <c>false</c> if out of range.</summary>
    Public Function [Get](index As Integer) As Object
        If index > _patternCount - 1 OrElse index < 0 Then
            Return False
        End If

        Dim segmentIndex = 0
        For Each generator In _generators
            Dim patternIndex = index - segmentIndex
            If patternIndex < generator.Count() Then
                Return generator.Get(patternIndex)
            End If
            segmentIndex += generator.Count()
        Next
        Return False
    End Function
End Class

