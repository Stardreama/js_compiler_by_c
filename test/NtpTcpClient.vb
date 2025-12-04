Imports System.IO
Imports System.Net.Sockets
Imports System.Text

Public Class NtpTcpClient
    Private Const ntpServerUrl As String = "time-c.nist.gov"
    Private Const ntpServerPort As Integer = 13

    Public Shared Function GetDate() As String
        Dim ntpResponse As StringBuilder
        Dim isoDate As String

        Try
            ntpResponse = New StringBuilder()

            Using client As New TcpClient(ntpServerUrl, ntpServerPort)
                While client.Connected
                    Using reader As New StreamReader(client.GetStream)
                        ntpResponse.Append(reader.ReadToEnd)
                    End Using
                End While
            End Using

            isoDate = FormatServerDate(ntpResponse.ToString())

            Return String.Format("NTP TCP date: {0}", isoDate)
        Catch ex As Exception
            Return String.Format("Error retrieving time from TCP Server {0}", ntpServerUrl)
        End Try
    End Function

    Private Shared Function FormatServerDate(ByVal response As String) As String
        ' ntpResponse: 59844 22-09-22 15:06:49 50 0 0 374.3 UTC(NIST)
        ' https://www.nist.gov/pml/time-and-frequency-division/time-distribution/internet-time-service-its
        Dim arrDate As String() = response.ToString().Split()
        Dim strDate As String = String.Format("{0} {1}", arrDate(2), arrDate(3))
        Dim d As Date = Date.Parse(strDate)

        ' ISO 8601 https://www.w3.org/TR/NOTE-datetime
        Return d.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
    End Function

End Class
