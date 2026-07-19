Public NotInheritable Class TokenOptions
    Public Property [String] As String
    Public Property StartLength As Integer?
    Public Property EndLength As Integer?
    Public Property Variants As List(Of String)
    Public Property Src As String = ""

    Public Shared Function Create(variants As List(Of String), startLength As Integer, endLength As Integer, src As String) As TokenOptions
        Return New TokenOptions With {
            .Variants = variants,
            .StartLength = startLength,
            .EndLength = endLength,
            .Src = src
        }
    End Function
End Class

Public NotInheritable Class Token
    Private ReadOnly _src As String
    Private ReadOnly _startLength As Integer
    Private ReadOnly _endLength As Integer
    Private ReadOnly _variants As List(Of String)
    Private ReadOnly _count As Integer

    Public Sub New(options As TokenOptions)
        _src = If(options.Src, "")
        _startLength = DefaultInteger(options.StartLength, 1)
        _endLength = DefaultInteger(options.EndLength, 1)
        If options.Variants IsNot Nothing Then
            _variants = New List(Of String)(options.Variants)
        Else
            _variants = New List(Of String)()
        End If

        Dim total = 0
        For length = _startLength To _endLength
            total += Pow(_variants.Count, length)
        Next
        _count = total
    End Sub

    Private Shared Function DefaultInteger(maybeValue As Integer?, fallback As Integer) As Integer
        If maybeValue.HasValue AndAlso maybeValue.Value >= 0 Then
            Return maybeValue.Value
        End If
        Return fallback
    End Function

    Private Shared Function Pow(baseValue As Integer, exp As Integer) As Integer
        Dim result = 1
        For i = 0 To exp - 1
            result *= baseValue
        Next
        Return result
    End Function

    Public Function Count() As Integer
        Return _count
    End Function

    Public Function Src() As String
        Return _src
    End Function

    Public Function [Get](index As Integer) As String
        If index > _count - 1 OrElse index < 0 Then
            Return ""
        End If

        If index = 0 AndAlso _startLength = 0 Then
            Return ""
        End If

        Dim indexWithOffset = index
        Dim stringLength = _startLength
        For stringLength = _startLength To _endLength
            Dim offsetCount = Pow(_variants.Count, stringLength)
            If indexWithOffset < offsetCount Then
                Exit For
            End If
            indexWithOffset -= offsetCount
        Next

        Dim chars(stringLength - 1) As String
        For i = 0 To stringLength - 1
            Dim variantIndex = indexWithOffset Mod _variants.Count
            indexWithOffset \= _variants.Count
            chars(i) = _variants(variantIndex)
        Next
        Return String.Concat(chars)
    End Function
End Class

