Public Class SimpleObject

#Region "Attributes"

    Private _firstField As String
    Private _secondField As String
    Private _thirdField As String

#End Region

#Region "Properties"

    Public ReadOnly Property FirstField As String
        Get
            Return _firstField
        End Get
    End Property

    Public ReadOnly Property SecondField As String
        Get
            Return _secondField
        End Get
    End Property

    Public ReadOnly Property ThirdField As String
        Get
            Return _thirdField
        End Get
    End Property

#End Region

#Region "Constructors"

    Public Sub New(firstField As String, secondField As String, thirdField As String)
        _firstField = firstField
        _secondField = secondField
        _thirdField = thirdField
    End Sub

#End Region

#Region "Methods"

    Public Overrides Function ToString() As String
        Return String.Format("{0},{1},{2}", firstField, secondField, thirdField)
    End Function

#End Region

End Class
