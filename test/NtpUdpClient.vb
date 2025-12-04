Imports System.Net
Imports System.Net.Sockets

Public Class NtpUdpClient
    Private Const ntpServerUrl As String = "ntp02.oal.ul.pt"
    Private Const ntpServerPort As Integer = 123
    Private Const timeOut As Integer = 5000

    Public Shared Function GetDate() As String
        Dim ntpIp As IPAddress
        Dim ipEndPoint As EndPoint
        Dim udpClient As UdpClient
        Dim bytes(47) As Byte
        Dim intPart As ULong
        Dim fractPart As ULong
        Dim milliseconds As Decimal
        Dim ntpDate As Date
        Dim isoDate As String

        Try
            ntpIp = Dns.GetHostEntry(ntpServerUrl).AddressList(0)
            ipEndPoint = New IPEndPoint(ntpIp, ntpServerPort)

            udpClient = New UdpClient()
            udpClient.Client.SendTimeout = timeOut
            udpClient.Client.ReceiveTimeout = timeOut
            udpClient.Connect(ipEndPoint)

            bytes(0) = &H1B 'LeapIndicator = 0 (no warning), VersionNum = 3 (IPv4 only), Mode = 3 (Client Mode)
            udpClient.Send(bytes, bytes.Length)

            bytes = udpClient.Receive(ipEndPoint)
            udpClient.Close()

            intPart = CULng(bytes(40)) << 24 Or CULng(bytes(41)) << 16 Or CULng(bytes(42)) << 8 Or bytes(43)
            fractPart = CULng(bytes(44)) << 24 Or CULng(bytes(45)) << 16 Or CULng(bytes(46)) << 8 Or bytes(47)
            milliseconds = (intPart * 1000) + ((fractPart * 1000) \ &H100000000L)
            ntpDate = (New Date(1900, 1, 1)).AddMilliseconds(milliseconds)

            ' ISO 8601 https://www.w3.org/TR/NOTE-datetime
            isoDate = ntpDate.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"

            Return String.Format("NTP UDP date: {0}", isoDate)
        Catch ex As Exception
            Return String.Format("Error retrieving time from UDP Server {0}", ntpServerUrl)
        End Try
    End Function

End Class
