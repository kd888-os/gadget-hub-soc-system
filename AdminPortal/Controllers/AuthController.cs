using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;
using AdminPortal.Models;

namespace AdminPortal.Controllers
{
    public class AuthController : Controller
    {
        private readonly HttpClient _httpClient;

        public AuthController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri("http://localhost:5001");
        }

        public IActionResult Login()
        {
            if (HttpContext.Session.GetInt32("AdminId") != null)
            {
                return RedirectToAction("Index", "Dashboard");
            }

            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Login(LoginViewModel model)
        {
            try
            {
                var response = await _httpClient.PostAsJsonAsync("/api/admin/login", new
                {
                    Username = model.Username,
                    Password = model.Password
                });

                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadFromJsonAsync<LoginResponse>();

                    HttpContext.Session.SetInt32("AdminId", result.AdminId);
                    HttpContext.Session.SetString("AdminName", result.FullName);
                    HttpContext.Session.SetString("Email", result.Email);

                    TempData["Success"] = $"Welcome, {result.FullName}!";
                    return RedirectToAction("Index", "Dashboard");
                }
                else
                {
                    TempData["Error"] = "Invalid username or password";
                    return View(model);
                }
            }
            catch
            {
                TempData["Error"] = "Unable to connect to authentication service";
                return View(model);
            }
        }

        public IActionResult Logout()
        {
            HttpContext.Session.Clear();
            TempData["Success"] = "You have been logged out successfully";
            return RedirectToAction("Login");
        }
    }

    public class LoginResponse
    {
        public int AdminId { get; set; }
        public string FullName { get; set; }
        public string Email { get; set; }
    }
}