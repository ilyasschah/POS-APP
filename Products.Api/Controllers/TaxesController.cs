using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.TaxesCommands;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Queries.TaxesQuery.Get;

namespace Products.Api.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TaxesController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<TaxDto>>> GetAllTaxes()
        {
            return Ok(await mediator.Send(new GetAllTaxesQuery()));
        }
        [HttpGet("{id}")]
        public IActionResult GetTaxById(int id)
        {
            // This method should return a specific tax by ID
            // For now, we will return a placeholder response
            return Ok(new { Message = $"This endpoint will return tax with ID {id}." });
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<TaxDto>> AddTax([FromBody] CreateTaxRequestDto createDto)
        {
            if (createDto == null)
            {
                return BadRequest("Invalid Tax data.");
            }
            var Query = new AddTaxQuery(createDto);
            var newTax = await mediator.Send(Query);
            return Ok(newTax);
        }

        [HttpPut("{id}")]
        public IActionResult UpdateTax(int id, [FromBody] object tax)
        {
            // This method should update an existing tax
            // For now, we will return a placeholder response
            return Ok(new { Message = $"Tax with ID {id} updated successfully." });
        }
        [HttpDelete("{id}")]
        public IActionResult DeleteTax(int id)
        {
            // This method should delete a tax by ID
            // For now, we will return a placeholder response
            return Ok(new { Message = $"Tax with ID {id} deleted successfully." });

        }
        [HttpGet("test")]
        public IActionResult TestEndpoint()
        {
            // This is a test endpoint to verify the controller is working
            return Ok(new { Message = "TaxesController is working!" });
        }
    }
}
