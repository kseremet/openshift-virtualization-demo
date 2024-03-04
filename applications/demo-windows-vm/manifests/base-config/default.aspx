<%@ Page Language="C#" %>
<!DOCTYPE html>
<html>
<head>
    <title>Server Information</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f0f0f0;
        }
        .container {
            width: 80%;
            margin: auto;
            padding: 20px;
        }
        h1 {
            color: #333;
            text-align: center;
        }
        p {
            font-size: 20px;
            color: #666;
            text-align: center;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Server Information</h1>
        <p>Hostname: <%= System.Environment.MachineName %></p>
        <p>IP Address: <%= GetIPv4Address() %></p>
    </div>
</body>
</html>

<script runat="server">
    protected string GetIPv4Address()
    {
        var hostEntry = System.Net.Dns.GetHostEntry(System.Environment.MachineName);
        foreach (var address in hostEntry.AddressList)
        {
            if (address.AddressFamily == System.Net.Sockets.AddressFamily.InterNetwork)
            {
                return address.ToString();
            }
        }
        return "No IPv4 address found";
    }
</script>
