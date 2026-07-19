Public NotInheritable Class Generator
    Private ReadOnly _tokens As List(Of Token)
    Private ReadOnly _count As Integer

    Public Sub New(inputPattern As String, dictionaries As IReadOnlyDictionary(Of String, List(Of String)))
        Source = inputPattern
        _tokens = ParsePattern.Parse(inputPattern, dictionaries)
        Dim total = 1
        For Each token In _tokens
            total *= token.Count()
        Next
        _count = total
    End Sub

    Public ReadOnly Property Source As String

    Public Function Count() As Integer
        Return _count
    End Function

    Public Function Tokens() As IReadOnlyList(Of Token)
        Return _tokens
    End Function

    Public Function [Get](index As Integer) As String
        If index > _count - 1 OrElse index < 0 Then
            Return ""
        End If

        Dim parts(_tokens.Count - 1) As String
        Dim indexWithOffset = index
        For i = 0 To _tokens.Count - 1
            Dim token = _tokens(i)
            parts(i) = token.Get(indexWithOffset Mod token.Count())
            indexWithOffset \= token.Count()
        Next
        Return String.Concat(parts)
    End Function
End Class

