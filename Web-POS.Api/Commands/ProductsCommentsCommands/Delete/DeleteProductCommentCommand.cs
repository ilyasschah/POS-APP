using MediatR;
using Api.Services;
using FluentValidation;

namespace Api.Commands.ProductsCommentsCommands.Delete
{
    public class DeleteProductCommentCommand : IRequest<bool>
    {
        public int Id { get; }
        public int CompanyId { get; }
        public DeleteProductCommentCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteProductCommentCommandHandler : IRequestHandler<DeleteProductCommentCommand, bool>
        {
            private readonly ProductCommentService _service;

            public DeleteProductCommentCommandHandler(ProductCommentService service)
            {
                _service = service;
            }

            public Task<bool> Handle(DeleteProductCommentCommand command, CancellationToken cancellationToken)
            {
                return _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
    public class DeleteProductCommentCommandValidator : AbstractValidator<DeleteProductCommentCommand>
    {
        public DeleteProductCommentCommandValidator()
        {
            RuleFor(c => c.Id).GreaterThan(0).WithMessage("Id must be valid.");
            RuleFor(c => c.CompanyId).GreaterThan(0).WithMessage("CompanyId must be valid.");
        }
    }
}
