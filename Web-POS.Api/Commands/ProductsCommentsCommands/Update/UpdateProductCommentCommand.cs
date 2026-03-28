using FluentValidation;
using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.ProductsCommentsCommands.Update
{
    public class UpdateProductCommentCommand : IRequest<bool>
    {
        public UpdateProductCommentRequest Request { get; }
        public int CompanyId { get; }

        public UpdateProductCommentCommand(UpdateProductCommentRequest request, int companyId)
        {
            Request = request;
            CompanyId = companyId;
        }

        public class UpdateProductCommentCommandHandler : IRequestHandler<UpdateProductCommentCommand, bool>
        {
            private readonly ProductCommentService _service;

            public UpdateProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(UpdateProductCommentCommand command, CancellationToken cancellationToken)
            {
                return _service.Update(command.Request, command.CompanyId);
            }
        }

        public class UpdateProductCommentCommandValidator : AbstractValidator<UpdateProductCommentCommand>
        {
            public UpdateProductCommentCommandValidator()
            {
                RuleFor(x => x.Request.ProductId).GreaterThan(0).WithMessage("Product ID must be valid.");
                RuleFor(x => x.Request.Comment).NotEmpty().WithMessage("Comment cannot be empty.");
                RuleFor(x => x.CompanyId).GreaterThan(0).WithMessage("Company ID must be valid.");
            }
        }
    }
}
