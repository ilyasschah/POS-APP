using MediatR;
using Microsoft.AspNetCore.Mvc;
using Products.Api.Commands.ProductsCommentsCommands.Add;
using Products.Api.Models;
using Products.Api.Queries.ProductCommentsQuery.Get;

namespace Products.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductCommentsController(IMediator mediator) : ControllerBase
    {
        [HttpGet("[action]")]
        public async Task<ActionResult<List<ProductCommentDto>>> GetAllProductComments()
        {
            return Ok(await mediator.Send(new GetAllProductCommentsQuery()));
        }
        [HttpPost("[action]")]
        public async Task<ActionResult<ProductCommentDto>> AddProductComment([FromBody] CreateProductCommentRequest createproductcommentrequest)
        {
            return Ok(await mediator.Send(new AddProductCommentcommand(createproductcommentrequest)));
        }
        //[HttpDelete("{id}")]
        //public async Task<ActionResult> DeleteProductComment(int id)
        //{
        //    try
        //    {
        //        var deleted = await _productCommentRepository.DeleteProductCommentAsync(id);
        //        if (!deleted)
        //            return NotFound($"Product comment with ID {id} not found.");

        //        return NoContent();
        //    }
        //    catch (Exception ex)
        //    {
        //        return StatusCode(500, $"Internal server error: {ex.Message}");
        //    }
        //}
    }
}